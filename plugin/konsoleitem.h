#pragma once
#include <QQuickItem>
#include <QPointer>

namespace KParts { class ReadOnlyPart; }
class QWidget;
class QWindow;

class KonsoleItem : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(QString workingDirectory READ workingDirectory WRITE setWorkingDirectory NOTIFY workingDirectoryChanged)

public:
    explicit KonsoleItem(QQuickItem *parent = nullptr);
    ~KonsoleItem() override;

    QString command() const { return m_command; }
    void setCommand(const QString &cmd);

    QString workingDirectory() const { return m_workingDir; }
    void setWorkingDirectory(const QString &dir);

    Q_INVOKABLE void start();
    Q_INVOKABLE void shutdown();

Q_SIGNALS:
    void commandChanged();
    void workingDirectoryChanged();
    void exited(int code);

protected:
    void geometryChange(const QRectF &newGeom, const QRectF &oldGeom) override;
    void itemChange(ItemChange change, const ItemChangeData &value) override;
    void keyPressEvent(QKeyEvent *event) override;
    void keyReleaseEvent(QKeyEvent *event) override;
    void focusInEvent(QFocusEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    bool eventFilter(QObject *watched, QEvent *event) override;

private Q_SLOTS:
    void onWindowVisibleChanged(bool visible);

private:
    void embedWidget();
    void detachWidget();
    void syncWidgetGeometry();

    QString m_command;
    QString m_workingDir;
    KParts::ReadOnlyPart *m_part = nullptr;
    QPointer<QWidget> m_partWidget;
    QPointer<QWidget> m_termDisplay;
    QWindow *m_embeddedWindow = nullptr;
    QPointer<QQuickWindow> m_watchedWindow;
    bool m_started = false;
};
