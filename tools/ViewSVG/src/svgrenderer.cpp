#include "svgrenderer.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QGuiApplication>
#include <QMutexLocker>
#include <QPainter>
#include <QScreen>
#include <QtConcurrent/QtConcurrent>

inline QImage generateCheckerboardTexture()
{
    QImage texture(SvgRenderer::CHECKERBOARD_SIZE * 2,
                   SvgRenderer::CHECKERBOARD_SIZE * 2,
                   QImage::Format_ARGB32);
    texture.fill(Qt::transparent);

    QPainter painter(&texture);
    QColor dark(220, 220, 220);
    QColor light(255, 255, 255);

    // Draw checker pattern
    painter.fillRect(0, 0, SvgRenderer::CHECKERBOARD_SIZE, SvgRenderer::CHECKERBOARD_SIZE, light);
    painter.fillRect(SvgRenderer::CHECKERBOARD_SIZE,
                     0,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     dark);
    painter.fillRect(0,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     dark);
    painter.fillRect(SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     SvgRenderer::CHECKERBOARD_SIZE,
                     light);

    return texture;
}

SvgRenderer::SvgRenderer(QQuickItem *parent)
    : QQuickPaintedItem(parent), m_CHECKERBOARD {QBrush(generateCheckerboardTexture())}
{
    // Initialize
    ResvgRenderer::initLog();

    // Enable antialiasing
    setAntialiasing(true);

    // Set default DPI based on screen
    if (QGuiApplication::primaryScreen()) {
        m_dpiRatio = QGuiApplication::primaryScreen()->devicePixelRatio();
        m_options.setDpi(96.0f * m_dpiRatio);
    }

    // Connect signals when geometry changes
    connect(this, &QQuickItem::widthChanged, this, &SvgRenderer::requestRender);
    connect(this, &QQuickItem::heightChanged, this, &SvgRenderer::requestRender);
}

SvgRenderer::~SvgRenderer()
{
    // Wait for any pending rendering to complete
    if (m_renderFuture.isRunning()) {
        m_renderFuture.waitForFinished();
    }
}

void SvgRenderer::paint(QPainter *painter)
{
    if (m_image.isNull()) {
        return;
    }

    QMutexLocker locker(&m_mutex);

    // Draw background based on selected mode
    QRectF targetRect = boundingRect();

    switch (m_background) {
    case White:
        painter->fillRect(targetRect, Qt::white);
        break;
    case CheckBoard: {
        // Use the checker pattern as a brush
        painter->fillRect(targetRect, this->m_CHECKERBOARD);
        break;
    }
    case None:
    default:
        // Draw nothing for background
        break;
    }

    // Calculate positioning based on fit mode
    if (m_fitToView && !m_image.isNull()) {
        QSizeF imgSize = m_image.size();
        QSizeF viewSize = size();

        float scaleX = viewSize.width() / imgSize.width();
        float scaleY = viewSize.height() / imgSize.height();
        float scale = qMin(scaleX, scaleY);

        QSizeF scaledSize = imgSize * scale;
        QPointF topLeft((viewSize.width() - scaledSize.width()) / 2,
                        (viewSize.height() - scaledSize.height()) / 2);

        QRectF destRect(topLeft, scaledSize);
        painter->drawImage(destRect, m_image);

        // Draw border if requested
        if (m_drawImageBorder) {
            painter->setPen(QPen(Qt::black, 1));
            painter->drawRect(destRect);
        }
    } else {
        // Original size centered
        QPointF pos((width() - m_image.width()) / 2, (height() - m_image.height()) / 2);

        painter->drawImage(pos, m_image);

        // Draw border if requested
        if (m_drawImageBorder) {
            painter->setPen(QPen(Qt::black, 1));
            painter->drawRect(QRectF(pos, m_image.size()));
        }
    }
}

void SvgRenderer::setFitToView(bool fit)
{
    if (m_fitToView == fit) {
        return;
    }

    m_fitToView = fit;
    emit fitToViewChanged();
    update();
}

void SvgRenderer::setBackground(Background bg)
{
    if (m_background == bg) {
        return;
    }

    m_background = bg;
    emit backgroundChanged();
    update();
}

void SvgRenderer::setDrawImageBorder(bool draw)
{
    if (m_drawImageBorder == draw) {
        return;
    }

    m_drawImageBorder = draw;
    emit drawImageBorderChanged();
    update();
}

void SvgRenderer::setSource(const QUrl &source)
{
    if (m_source == source) {
        return;
    }

    // Stop any ongoing rendering
    if (m_renderFuture.isRunning()) {
        m_renderFuture.waitForFinished();
    }

    m_source = source;
    emit sourceChanged();

    if (source.isEmpty()) {
        m_image = QImage();
        m_errorMsg.clear();
        update();
        return;
    }

    // Set loading state
    m_loading = true;
    emit loadingChanged();
    emit renderStarted();

    // Create a watcher to get results from future
    auto *watcher = new QFutureWatcher<void>();

    // Process file loading and rendering asynchronously
    m_renderFuture = QtConcurrent::run([this, source]() {
        QString errMsg;
        QImage result;

        try {
            // Create a local renderer instance
            auto renderer = std::make_unique<ResvgRenderer>();

            // Prepare options
            ResvgOptions opts;
            if (QGuiApplication::primaryScreen()) {
                opts.setDpi(96.0f * QGuiApplication::primaryScreen()->devicePixelRatio());
            }

            // Load the SVG from URL
            QString path;
            if (source.isLocalFile()) {
                path = source.toLocalFile();

                // Set resources directory for relative paths in SVG
                QFileInfo fileInfo(path);
                opts.setResourcesDir(fileInfo.absolutePath());
            } else {
                // Handle remote URLs or other protocols
                QFile file(source.toString());
                if (!file.open(QIODevice::ReadOnly)) {
                    errMsg = tr("Failed to open file: %1").arg(source.toString());
                    return;
                }

                QByteArray data = file.readAll();
                if (!renderer->load(data, opts)) {
                    errMsg = renderer->errorString();
                    return;
                }
            }

            // Load local file if we have a path
            if (!path.isEmpty() && !renderer->load(path, opts)) {
                errMsg = renderer->errorString();
                return;
            }

            // Check if renderer is valid and not empty
            if (!renderer->isValid() || renderer->isEmpty()) {
                errMsg = renderer->errorString();
                if (errMsg.isEmpty()) {
                    errMsg = tr("SVG file is empty or invalid");
                }
                return;
            }

            // Render the SVG to an image
            QMutexLocker locker(&m_mutex);

            // Store renderer for future access
            m_renderer = std::move(renderer);

            // Get SVG size
            m_imageSize = m_renderer->defaultSize();

            // Render to image at original size
            result = m_renderer->renderToImage(m_imageSize);
        } catch (const std::exception &e) {
            errMsg = tr("Exception while loading SVG: %1").arg(e.what());
        }

        // Handle results on the main thread
        QMetaObject::invokeMethod(this, [this, errMsg, result]() {
            // Reset loading state
            m_loading = false;
            emit loadingChanged();

            if (!errMsg.isEmpty()) {
                // Handle error
                m_errorMsg = errMsg;
                emit errorMessageChanged();
                emit loadFailed(errMsg);
            } else {
                // Store successful result
                QMutexLocker locker(&m_mutex);
                m_image = result;
                m_errorMsg.clear();

                emit loadSucceeded();
                emit imageSizeChanged();
                update();
            }

            emit renderFinished();
        });
    });

    // Set up watcher to automatically delete itself when done
    connect(watcher, &QFutureWatcher<void>::finished, watcher, &QFutureWatcher<void>::deleteLater);
    watcher->setFuture(m_renderFuture);
}

void SvgRenderer::loadDataFromBase64(const QString &dataBase64)
{
    if (dataBase64.isEmpty()) {
        return;
    }

    // Decode base64 string
    QByteArray data = QByteArray::fromBase64(dataBase64.toUtf8());
    if (data.isEmpty()) {
        handleLoadResult(tr("Invalid Base64 data"));
        return;
    }

    // Set loading state
    m_loading = true;
    emit loadingChanged();
    emit renderStarted();

    // Create a watcher to get results from future
    auto *watcher = new QFutureWatcher<void>();

    // Process data loading and rendering asynchronously
    m_renderFuture = QtConcurrent::run([this, data]() {
        QString errMsg;
        QImage result;

        try {
            // Create a local renderer instance
            auto renderer = std::make_unique<ResvgRenderer>();

            // Prepare options
            ResvgOptions opts;
            if (QGuiApplication::primaryScreen()) {
                opts.setDpi(96.0f * QGuiApplication::primaryScreen()->devicePixelRatio());
            }

            // Load the SVG from data
            if (!renderer->load(data, opts)) {
                errMsg = renderer->errorString();
                return;
            }

            // Check if renderer is valid and not empty
            if (!renderer->isValid() || renderer->isEmpty()) {
                errMsg = renderer->errorString();
                if (errMsg.isEmpty()) {
                    errMsg = tr("SVG data is empty or invalid");
                }
                return;
            }

            // Render the SVG to an image
            QMutexLocker locker(&m_mutex);

            // Store renderer for future access
            m_renderer = std::move(renderer);

            // Get SVG size
            m_imageSize = m_renderer->defaultSize();

            // Render to image at original size
            result = m_renderer->renderToImage(m_imageSize);
        } catch (const std::exception &e) {
            errMsg = tr("Exception while loading SVG: %1").arg(e.what());
        }

        // Handle results on the main thread
        QMetaObject::invokeMethod(this, [this, errMsg, result]() {
            // Reset loading state
            m_loading = false;
            emit loadingChanged();

            if (!errMsg.isEmpty()) {
                // Handle error
                m_errorMsg = errMsg;
                emit errorMessageChanged();
                emit loadFailed(errMsg);
            } else {
                // Store successful result
                QMutexLocker locker(&m_mutex);
                m_image = result;
                m_errorMsg.clear();

                emit loadSucceeded();
                emit imageSizeChanged();
                update();
            }

            emit renderFinished();
        });
    });

    // Set up watcher to automatically delete itself when done
    connect(watcher, &QFutureWatcher<void>::finished, watcher, &QFutureWatcher<void>::deleteLater);
    watcher->setFuture(m_renderFuture);
}

void SvgRenderer::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);

    if (newGeometry.size() != oldGeometry.size()) {
        requestRender();
    }
}

void SvgRenderer::requestRender()
{
    // Only render if we have a valid size and image
    if (width() <= 0 || height() <= 0 || !m_renderer || m_image.isNull()) {
        return;
    }

    update();
}

void SvgRenderer::handleLoadResult(const QString &errMsg)
{
    // Reset loading state
    m_loading = false;
    emit loadingChanged();

    if (!errMsg.isEmpty()) {
        // Handle error
        m_errorMsg = errMsg;
        emit errorMessageChanged();
        emit loadFailed(errMsg);
    } else {
        // Clear error message on success
        m_errorMsg.clear();
        emit loadSucceeded();
    }

    emit renderFinished();
    update();
}

QRect SvgRenderer::viewBox() const
{
    if (m_renderer) {
        return m_renderer->viewBox();
    }
    return QRect();
}
