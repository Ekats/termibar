#include "konsoleitem.h"

#include <KParts/ReadOnlyPart>
#include <KParts/PartLoader>
#include <KPluginMetaData>
#include <kde_terminal_interface.h>

#include <QQuickWindow>
#include <QWidget>
#include <QWindow>
#include <QDir>
#include <QProcess>
#include <QKeyEvent>
#include <QCoreApplication>
#include <QDebug>

static QWidget *findTerminalDisplay(QWidget *root) {
    if (!root) return nullptr;
    for (auto *child : root->findChildren<QWidget *>()) {
        if (QString::fromUtf8(child->metaObject()->className())
                .contains(QLatin1String("TerminalDisplay"))) {
            return child;
        }
    }
    QWidget *best = root;
    for (auto *child : root->findChildren<QWidget *>()) {
        if (child->focusPolicy() != Qt::NoFocus) {
            best = child;
        }
    }
    return best;
}

KonsoleItem::KonsoleItem(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, false);
    setFlag(ItemAcceptsInputMethod, true);
    setAcceptedMouseButtons(Qt::AllButtons);
    setFiltersChildMouseEvents(false);
    setFocus(true);
    setActiveFocusOnTab(true);
}

KonsoleItem::~KonsoleItem()
{
    detachWidget();
    delete m_part;
}

void KonsoleItem::setCommand(const QString &cmd)
{
    if (m_command == cmd) return;
    m_command = cmd;
    Q_EMIT commandChanged();
}

void KonsoleItem::setWorkingDirectory(const QString &dir)
{
    if (m_workingDir == dir) return;
    m_workingDir = dir;
    Q_EMIT workingDirectoryChanged();
}

void KonsoleItem::start()
{
    if (m_part) return;

    const KPluginMetaData metaData(QStringLiteral("kf6/parts/konsolepart"));
    if (!metaData.isValid()) {
        qWarning() << "Termibar: konsolepart metadata not found";
        return;
    }

    auto result = KParts::PartLoader::instantiatePart<KParts::ReadOnlyPart>(
        metaData, nullptr, this);

    if (!result.plugin) {
        qWarning() << "Termibar: failed to load konsolepart:" << result.errorString;
        return;
    }

    m_part = result.plugin;
    m_partWidget = m_part->widget();

    if (!m_partWidget) {
        qWarning() << "Termibar: konsolepart has no widget";
        delete m_part;
        m_part = nullptr;
        return;
    }

    auto *termIface = qobject_cast<TerminalInterface *>(m_part);
    if (termIface) {
        QString dir = m_workingDir.isEmpty() ? QDir::homePath() : m_workingDir;
        if (m_command.isEmpty() || m_command == QLatin1String("/bin/bash")) {
            termIface->showShellInDir(dir);
        } else {
            QString cmd = m_command;
            if (cmd.startsWith(QLatin1Char('~')))
                cmd = QDir::homePath() + cmd.mid(1);
            QString shell = qEnvironmentVariable("SHELL", QStringLiteral("/bin/sh"));
            qDebug() << "Termibar: startProgram cmd:" << cmd << "shell:" << shell;
            termIface->startProgram(shell, {shell, QStringLiteral("-lc"), cmd});
        }
    }

    connect(m_part, &QObject::destroyed, this, [this]() {
        detachWidget();
        m_part = nullptr;
        // m_partWidget auto-nulls via QPointer when widget is destroyed with the part
        m_started = false;
        Q_EMIT exited(0);
    });

    m_started = true;

    if (window()) {
        embedWidget();
    }
}

void KonsoleItem::detachWidget()
{
    if (m_watchedWindow) {
        disconnect(m_watchedWindow, &QWindow::visibleChanged,
                   this, &KonsoleItem::onWindowVisibleChanged);
        m_watchedWindow = nullptr;
    }
    if (m_termDisplay) {
        m_termDisplay->removeEventFilter(this);
        m_termDisplay = nullptr;
    }
    if (m_embeddedWindow) {
        m_embeddedWindow->setParent(nullptr);
        m_embeddedWindow = nullptr;
    }
    if (m_partWidget) {
        m_partWidget->hide();
    }
}

void KonsoleItem::embedWidget()
{
    if (!m_partWidget || !window() || m_embeddedWindow) return;

    m_partWidget->winId();
    QWindow *widgetWindow = m_partWidget->windowHandle();
    if (!widgetWindow) {
        qWarning() << "Termibar: could not get widget window handle";
        return;
    }

    widgetWindow->setParent(window());
    m_embeddedWindow = widgetWindow;

    m_watchedWindow = window();
    // Qt::UniqueConnection guards against double-connection during the
    // null→same-window ItemSceneChange sequence (detach then re-embed into
    // the same QWindow).
    connect(m_watchedWindow, &QWindow::visibleChanged,
            this, &KonsoleItem::onWindowVisibleChanged,
            Qt::UniqueConnection);

    m_partWidget->show();

    m_termDisplay = findTerminalDisplay(m_partWidget);
    if (m_termDisplay)
        m_termDisplay->installEventFilter(this);

    syncWidgetGeometry();

    // Grab QML keyboard focus so keyPressEvent forwards to the terminal.
    // This fires focusInEvent, which sends FocusIn to m_termDisplay so
    // Konsole's TerminalDisplay starts processing key events.
    forceActiveFocus(Qt::OtherFocusReason);
}

void KonsoleItem::syncWidgetGeometry()
{
    if (!m_embeddedWindow || !window()) return;

    QPointF scenePos = mapToScene(QPointF(0, 0));
    QPoint windowPos = scenePos.toPoint();

    m_embeddedWindow->setGeometry(
        windowPos.x(), windowPos.y(),
        static_cast<int>(width()), static_cast<int>(height()));
}

void KonsoleItem::geometryChange(const QRectF &newGeom, const QRectF &oldGeom)
{
    QQuickItem::geometryChange(newGeom, oldGeom);
    syncWidgetGeometry();
}

void KonsoleItem::itemChange(ItemChange change, const ItemChangeData &value)
{
    QQuickItem::itemChange(change, value);

    switch (change) {
    case ItemSceneChange:
        if (!value.window) {
            detachWidget();
        } else if (m_started) {
            if (m_embeddedWindow) {
                // Window object changed (e.g. reparented to a different QQuickWindow).
                // Update the visibleChanged watch before re-parenting.
                if (m_watchedWindow && m_watchedWindow != value.window) {
                    disconnect(m_watchedWindow, &QWindow::visibleChanged,
                               this, &KonsoleItem::onWindowVisibleChanged);
                    m_watchedWindow = nullptr;
                }
                m_embeddedWindow->setParent(value.window);
                m_watchedWindow = value.window;
                connect(m_watchedWindow, &QWindow::visibleChanged,
                        this, &KonsoleItem::onWindowVisibleChanged,
                        Qt::UniqueConnection);
                syncWidgetGeometry();
            } else {
                embedWidget();
            }
        }
        break;

    case ItemVisibleHasChanged:
        // This fires when the QML item's own visible property (or a parent
        // item's) changes — e.g. StackLayout hiding a non-active tab.
        // It does NOT fire when the QQuickWindow hides/shows (popup open/close),
        // which is handled by onWindowVisibleChanged.
        // Show/hide the widget to prevent inactive tabs' subsurfaces from
        // overlapping the active terminal. Do NOT detach the subsurface —
        // that would destroy the wl_subsurface relationship.
        if (!m_partWidget) break;
        if (value.boolValue) {
            m_partWidget->show();
            syncWidgetGeometry();
            forceActiveFocus(Qt::OtherFocusReason);
            if (m_termDisplay) {
                QFocusEvent focusIn(QEvent::FocusIn, Qt::OtherFocusReason);
                QCoreApplication::sendEvent(m_termDisplay, &focusIn);
            }
        } else {
            m_partWidget->hide();
        }
        break;

    default:
        break;
    }
}

void KonsoleItem::onWindowVisibleChanged(bool visible)
{
    if (!visible || !m_partWidget || !m_watchedWindow || !m_embeddedWindow)
        return;

    // Re-parent subsurface into the new Wayland parent surface.
    m_embeddedWindow->setParent(m_watchedWindow);

    if (!isVisible()) {
        // Tab is not currently active — keep the widget hidden so its
        // subsurface doesn't overlap the visible terminal.
        m_partWidget->hide();
        return;
    }

    // The AppletPopup QQuickWindow is persistent, but its Wayland xdg_toplevel
    // surface is destroyed on close and recreated on open. Calling
    // setParent(same_QWindow_pointer) alone may be a no-op in Qt's Wayland
    // backend if the pointer hasn't changed — even though the underlying Wayland
    // surface is now a different object. hide()+show() forces Qt to destroy and
    // recreate the platform window (wl_surface + wl_subsurface), causing the
    // new subsurface to be properly parented to the current surface of
    // m_watchedWindow. If this hypothesis is wrong, replace with
    // m_partWidget->windowHandle()->destroy() + m_partWidget->show().
    m_partWidget->hide();
    m_partWidget->show();
    syncWidgetGeometry();

    // After hide/show, TerminalDisplay loses its internal focus state.
    // forceActiveFocus fires focusInEvent if we didn't already have activeFocus;
    // the explicit sendEvent covers the case where we already did.
    forceActiveFocus(Qt::OtherFocusReason);
    if (m_termDisplay) {
        QFocusEvent focusIn(QEvent::FocusIn, Qt::OtherFocusReason);
        QCoreApplication::sendEvent(m_termDisplay, &focusIn);
    }
}

void KonsoleItem::keyPressEvent(QKeyEvent *event)
{
    if (!m_termDisplay) {
        QQuickItem::keyPressEvent(event);
        return;
    }
    auto *cloned = new QKeyEvent(event->type(), event->key(), event->modifiers(),
                                  event->text(), event->isAutoRepeat(), event->count());
    QCoreApplication::postEvent(m_termDisplay, cloned);
    event->accept();
}

void KonsoleItem::keyReleaseEvent(QKeyEvent *event)
{
    if (!m_termDisplay) {
        QQuickItem::keyReleaseEvent(event);
        return;
    }
    auto *cloned = new QKeyEvent(event->type(), event->key(), event->modifiers(),
                                  event->text(), event->isAutoRepeat(), event->count());
    QCoreApplication::postEvent(m_termDisplay, cloned);
    event->accept();
}

void KonsoleItem::focusInEvent(QFocusEvent *)
{
    if (!m_termDisplay) return;
    QFocusEvent focusIn(QEvent::FocusIn, Qt::OtherFocusReason);
    QCoreApplication::sendEvent(m_termDisplay, &focusIn);
}

bool KonsoleItem::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_termDisplay && event->type() == QEvent::FocusOut) {
        auto *fe = static_cast<QFocusEvent *>(event);
        if (fe->reason() != Qt::PopupFocusReason)
            return true;
    }
    return QQuickItem::eventFilter(watched, event);
}

void KonsoleItem::mousePressEvent(QMouseEvent *event)
{
    forceActiveFocus(Qt::MouseFocusReason);
    event->accept();
}

void KonsoleItem::shutdown()
{
    detachWidget();
    if (m_part) {
        // Disconnect the destroyed lambda so it doesn't emit exited() during
        // an explicit config-driven shutdown — the session is being removed,
        // not exiting naturally.
        disconnect(m_part, &QObject::destroyed, this, nullptr);
        delete m_part;
        m_part = nullptr;
    }
    m_started = false;
}
