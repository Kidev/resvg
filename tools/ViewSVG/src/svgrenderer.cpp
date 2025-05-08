#include "svgrenderer.hpp"

#include <QDebug>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMimeData>
#include <QPainter>
#include <QRegularExpression>
#include <QScreen>
#include <QUrl>

// SvgRendererWorker implementation
SvgRendererWorker::SvgRendererWorker(QObject *parent)
    : QObject(parent), m_dpiRatio(QGuiApplication::primaryScreen()->devicePixelRatio())
{
    m_opt.loadSystemFonts();
}

SvgRendererWorker::~SvgRendererWorker() {}

QRect SvgRendererWorker::viewBox() const
{
    QMutexLocker lock(&m_mutex);
    return m_renderer.viewBox();
}

QString SvgRendererWorker::loadData(const QByteArray &data)
{
    QMutexLocker lock(&m_mutex);

    m_renderer.load(data, m_opt);
    if (!m_renderer.isValid()) {
        return m_renderer.errorString();
    }

    return QString();
}

QString SvgRendererWorker::loadFile(const QString &path)
{
    QMutexLocker lock(&m_mutex);

    m_opt.setResourcesDir(QFileInfo(path).absolutePath());
    m_renderer.load(path, m_opt);
    if (!m_renderer.isValid()) {
        return m_renderer.errorString();
    }

    return QString();
}

void SvgRendererWorker::render(const QSize &viewSize)
{
    QMutexLocker lock(&m_mutex);

    if (m_renderer.isEmpty()) {
        return;
    }

    QElapsedTimer timer;
    timer.start();

    const auto s = m_renderer.defaultSize().scaled(viewSize, Qt::KeepAspectRatio);
    auto img = m_renderer.renderToImage(s * m_dpiRatio);
    img.setDevicePixelRatio(m_dpiRatio);

    qDebug() << QString("Render in %1ms").arg(timer.elapsed());

    emit rendered(img);
}

// SvgRenderer implementation
static QImage genCheckedTexture()
{
    int l = 20;

    QImage pix = QImage(l, l, QImage::Format_RGB32);
    int b = pix.width() / 2.0;
    pix.fill(QColor("#c0c0c0"));

    QPainter p;
    p.begin(&pix);
    p.fillRect(QRect(0, 0, b, b), QColor("#808080"));
    p.fillRect(QRect(b, b, b, b), QColor("#808080"));
    p.end();

    return pix;
}

void SvgRenderer::init()
{
    ResvgRenderer::initLog();
}

SvgRenderer::SvgRenderer(QQuickItem *parent)
    : QQuickPaintedItem(parent)
    , m_checkboardImg(genCheckedTexture())
    , m_workerThread(new QThread(this))
    , m_worker(new SvgRendererWorker())
    , m_resizeTimer(new QTimer(this))
{
    setAcceptDrops(true);
    setAntialiasing(true);

    m_worker->moveToThread(m_workerThread);
    m_workerThread->start();

    m_dpiRatio = QGuiApplication::primaryScreen()->devicePixelRatio();

    connect(m_worker, &SvgRendererWorker::rendered, this, &SvgRenderer::onRendered);

    m_resizeTimer->setSingleShot(true);
    connect(m_resizeTimer, &QTimer::timeout, this, &SvgRenderer::requestUpdate);

    m_spinnerTimer.setInterval(100);
    connect(&m_spinnerTimer, &QTimer::timeout, this, &SvgRenderer::updateImage);
}

SvgRenderer::~SvgRenderer()
{
    m_workerThread->quit();
    m_workerThread->wait(10000);
    delete m_worker;
}

void SvgRenderer::paint(QPainter *painter)
{
    painter->setRenderHint(QPainter::Antialiasing);

    // Paint background
    switch (m_background) {
    case Background::None:
        // No background
        break;
    case Background::White:
        painter->fillRect(contentsBoundingRect(), Qt::white);
        break;
    case Background::CheckBoard:
        painter->fillRect(contentsBoundingRect(), QBrush(m_checkboardImg));
        break;
    }

    if (m_image.isNull() && !m_loading) {
        // No image, show instruction
        painter->setPen(Qt::black);
        painter->drawText(contentsBoundingRect(), Qt::AlignCenter, "Drop an SVG image here.");
    } else if (m_loading) {
        // Show spinner
        drawSpinner(*painter);
    } else {
        // Show image
        QRectF imgRect(0, 0, m_image.width() / m_dpiRatio, m_image.height() / m_dpiRatio);
        QRectF targetRect = imgRect;

        // Center the image in the view
        targetRect.moveLeft((width() - targetRect.width()) / 2);
        targetRect.moveTop((height() - targetRect.height()) / 2);

        painter->drawImage(targetRect.topLeft(), m_image);

        if (m_drawImageBorder) {
            painter->setRenderHint(QPainter::Antialiasing, false);
            painter->setPen(Qt::green);
            painter->setBrush(Qt::NoBrush);
            painter->drawRect(targetRect);
        }
    }
}

void SvgRenderer::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);

    if (newGeometry.size() != oldGeometry.size()) {
        m_resizeTimer->start(200);
    }
}

void SvgRenderer::setFitToView(bool fit)
{
    if (m_fitToView != fit) {
        m_fitToView = fit;
        requestUpdate();
        emit fitToViewChanged();
    }
}

void SvgRenderer::setBackground(Background bg)
{
    if (m_background != bg) {
        m_background = bg;
        update();
        emit backgroundChanged();
    }
}

void SvgRenderer::setDrawImageBorder(bool draw)
{
    if (m_drawImageBorder != draw) {
        m_drawImageBorder = draw;
        update();
        emit drawImageBorderChanged();
    }
}

void SvgRenderer::setSource(const QString &source)
{
    if (m_source != source) {
        m_source = source;

        if (source.startsWith("data:")) {
            // Handle data URL
            QRegularExpression re("data:image/svg\\+xml;base64,(.*)");
            QRegularExpressionMatch match = re.match(source);
            if (match.hasMatch()) {
                QByteArray data = QByteArray::fromBase64(match.captured(1).toUtf8());
                const QString errMsg = m_worker->loadData(data);
                afterLoad(errMsg);
            } else {
                afterLoad("Invalid data URL format");
            }
        } else {
            // Handle file URL or path
            QString filePath = source;
            if (source.startsWith("file:///")) {
                filePath = QUrl(source).toLocalFile();
            }

            const QString errMsg = m_worker->loadFile(filePath);
            afterLoad(errMsg);
        }

        emit sourceChanged();
    }
}

void SvgRenderer::loadDataFromQml(const QString &dataBase64)
{
    QByteArray data = QByteArray::fromBase64(dataBase64.toUtf8());
    const QString errMsg = m_worker->loadData(data);
    afterLoad(errMsg);
}

void SvgRenderer::afterLoad(const QString &errMsg)
{
    m_image = QImage();
    m_errorMsg = errMsg;

    if (errMsg.isEmpty()) {
        m_hasImage = true;
        requestUpdate();
    } else {
        m_hasImage = false;
        emit loadFailed(errMsg);
        emit errorMessageChanged();
        update();
    }
}

void SvgRenderer::requestUpdate()
{
    if (!m_hasImage) {
        return;
    }

    QSize s;
    if (m_fitToView) {
        s = QSize(width(), height());
    } else {
        s = m_worker->viewBox().size();
    }

    if (s.isEmpty() || (s * m_dpiRatio == m_image.size())) {
        return;
    }

    m_loading = true;
    emit loadingChanged();
    m_spinnerTimer.start();
    update();

    // Run method in the worker thread
    QMetaObject::invokeMethod(m_worker, [this, s]() { m_worker->render(s); }, Qt::QueuedConnection);
}

void SvgRenderer::onRendered(const QImage &img)
{
    m_image = img;
    m_loading = false;
    emit loadingChanged();
    m_spinnerTimer.stop();
    update();
}

void SvgRenderer::updateImage()
{
    m_spinnerAngle = (m_spinnerAngle + 30) % 360;
    update();
}

void SvgRenderer::drawSpinner(QPainter &p)
{
    const int outerRadius = 20;
    const int innerRadius = outerRadius * 0.45;

    const int capsuleHeight = outerRadius - innerRadius;
    const int capsuleWidth = capsuleHeight * 0.35;
    const int capsuleRadius = capsuleWidth / 2;

    for (int i = 0; i < 12; ++i) {
        QColor color = Qt::black;
        color.setAlphaF(1.0f - (i / 12.0f));
        p.setPen(Qt::NoPen);
        p.setBrush(color);
        p.save();
        p.translate(width() / 2, height() / 2);
        p.rotate(m_spinnerAngle - i * 30.0f);
        p.drawRoundedRect(-capsuleWidth * 0.5,
                          -(innerRadius + capsuleHeight),
                          capsuleWidth,
                          capsuleHeight,
                          capsuleRadius,
                          capsuleRadius);
        p.restore();
    }
}
