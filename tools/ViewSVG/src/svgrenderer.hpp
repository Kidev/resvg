#pragma once

#include <QBrush>
#include <QFuture>
#include <QImage>
#include <QMutex>
#include <QQuickPaintedItem>
#include <QRect>
#include <QSize>
#include <QUrl>

#include <ResvgQt.h>

class SvgRenderer : public QQuickPaintedItem
{
    Q_OBJECT
    // Properties
    Q_PROPERTY(bool fitToView READ fitToView WRITE setFitToView NOTIFY fitToViewChanged)
    Q_PROPERTY(Background background READ background WRITE setBackground NOTIFY backgroundChanged)
    Q_PROPERTY(bool drawImageBorder READ drawImageBorder WRITE setDrawImageBorder NOTIFY
                   drawImageBorderChanged)
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool loading READ isLoading NOTIFY loadingChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QRect viewBox READ viewBox NOTIFY viewBoxChanged)
    Q_PROPERTY(QSize imageSize READ imageSize NOTIFY imageSizeChanged)

public:
    enum Background {
        None = 0,
        White = 1,
        CheckBoard = 2
    };
    Q_ENUM(Background)

    explicit SvgRenderer(QQuickItem *parent = nullptr);
    ~SvgRenderer() override;

    // QQuickPaintedItem interface
    void paint(QPainter *painter) override;

    // Property getters/setters
    bool fitToView() const { return m_fitToView; }
    void setFitToView(bool fit);

    Background background() const { return m_background; }
    void setBackground(Background bg);

    bool drawImageBorder() const { return m_drawImageBorder; }
    void setDrawImageBorder(bool draw);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);

    bool isLoading() const { return m_loading; }
    QString errorMessage() const { return m_errorMsg; }
    QRect viewBox() const;
    QSize imageSize() const { return m_imageSize; }

    // Methods
    Q_INVOKABLE void loadDataFromBase64(const QString &dataBase64);

    static const int CHECKERBOARD_SIZE {20};

signals:
    void fitToViewChanged();
    void backgroundChanged();
    void drawImageBorderChanged();
    void sourceChanged();
    void loadingChanged();
    void errorMessageChanged();
    void viewBoxChanged();
    void imageSizeChanged();

    void loadFailed(const QString &error);
    void loadSucceeded();
    void renderStarted();
    void renderFinished();

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void requestRender();
    void handleLoadResult(const QString &errMsg);

    // Core SVG rendering components
    ResvgOptions m_options;
    std::unique_ptr<ResvgRenderer> m_renderer;
    mutable QMutex m_mutex;

    // State variables
    QUrl m_source;
    QString m_errorMsg;
    bool m_fitToView {true};
    Background m_background {CheckBoard};
    bool m_drawImageBorder {false};
    bool m_loading {false};
    QImage m_image;
    QSize m_imageSize;
    float m_dpiRatio {1.0f};

    // Async operation tracking
    QFuture<void> m_renderFuture;

    // Constants
    const QBrush m_CHECKERBOARD;
};
