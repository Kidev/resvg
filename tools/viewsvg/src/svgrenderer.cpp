// Copyright 2025 the Resvg Authors
// SPDX-License-Identifier: Apache-2.0 OR MIT

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

SvgRenderer::SvgRenderer(QQuickItem *parent)
    : QQuickPaintedItem(parent)
    , CHECKBOARD_BRUSH{QBrush(generateCheckerboardTexture(SvgRenderer::CHECKBOARD_SIZE))}
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

    // Connect internal signals for thread communication
    connect(this, &SvgRenderer::loadResultSignal, this, &SvgRenderer::handleLoadResult);
    connect(this, &SvgRenderer::imageLoadedSignal, this, &SvgRenderer::handleImageLoaded);
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
    QRectF targetRect{boundingRect()};

    switch (m_background) {
    case White:
        painter->fillRect(targetRect, Qt::white);
        break;
    case CheckBoard: {
        painter->fillRect(targetRect, this->CHECKBOARD_BRUSH);
        break;
    }
    case None:
    default:
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
        QSize imageSize;

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
                    emit loadResultSignal(errMsg);
                    return;
                }

                QByteArray data = file.readAll();
                if (!renderer->load(data, opts)) {
                    errMsg = renderer->errorString();
                    emit loadResultSignal(errMsg);
                    return;
                }
            }

            // Load local file if we have a path
            if (!path.isEmpty() && !renderer->load(path, opts)) {
                errMsg = renderer->errorString();
                emit loadResultSignal(errMsg);
                return;
            }

            // Check if renderer is valid and not empty
            if (!renderer->isValid() || renderer->isEmpty()) {
                errMsg = renderer->errorString();
                if (errMsg.isEmpty()) {
                    errMsg = tr("SVG file is empty or invalid");
                }
                emit loadResultSignal(errMsg);
                return;
            }

            // Get SVG size
            imageSize = renderer->defaultSize();

            // Render the SVG to an image
            QMutexLocker locker(&m_mutex);

            // Store renderer for future access
            m_renderer = std::move(renderer);

            // Render to image at original size
            result = m_renderer->renderToImage(imageSize);

            // Emit signal with results (will be handled on main thread)
            emit imageLoadedSignal(result, imageSize);
        } catch (const std::exception &e) {
            errMsg = tr("Exception while loading SVG: %1").arg(e.what());
            emit loadResultSignal(errMsg);
        }
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
        QSize imageSize;

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
                emit loadResultSignal(errMsg);
                return;
            }

            // Check if renderer is valid and not empty
            if (!renderer->isValid() || renderer->isEmpty()) {
                errMsg = renderer->errorString();
                if (errMsg.isEmpty()) {
                    errMsg = tr("SVG data is empty or invalid");
                }
                emit loadResultSignal(errMsg);
                return;
            }

            // Render the SVG to an image
            QMutexLocker locker(&m_mutex);

            // Store renderer for future access
            m_renderer = std::move(renderer);

            // Get SVG size
            imageSize = m_renderer->defaultSize();

            // Render to image at original size
            result = m_renderer->renderToImage(imageSize);

            // Emit signal with results (will be handled on main thread)
            emit imageLoadedSignal(result, imageSize);
        } catch (const std::exception &e) {
            errMsg = tr("Exception while loading SVG: %1").arg(e.what());
            emit loadResultSignal(errMsg);
        }
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

void SvgRenderer::handleImageLoaded(const QImage &image, const QSize &size)
{
    // Reset loading state
    m_loading = false;
    emit loadingChanged();

    // Store successful result
    QMutexLocker locker(&m_mutex);
    m_image = image;
    m_imageSize = size;
    m_errorMsg.clear();

    emit loadSucceeded();
    emit imageSizeChanged();
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

inline const QImage generateCheckerboardTexture(int size)
{
    QImage texture(size * 2, size * 2, QImage::Format_ARGB32);
    texture.fill(Qt::transparent);

    QPainter painter(&texture);
    QColor dark(220, 220, 220);
    QColor light(255, 255, 255);

    // Draw checker pattern
    painter.fillRect(0, 0, size, size, light);
    painter.fillRect(size, 0, size, size, dark);
    painter.fillRect(0, size, size, size, dark);
    painter.fillRect(size, size, size, size, light);

    return texture;
}
