#include <QApplication>
#include <QQmlApplicationEngine>
#include <QDebug>

int main(int argc, char *argv[])
{
    // QApplication (not QGuiApplication) needed for QWidget embedding
    QApplication app(argc, argv);

    QQmlApplicationEngine engine;

    // Add build directory so it finds org/termibar/ QML module
    engine.addImportPath(QCoreApplication::applicationDirPath());

    // test.qml is alongside the source files
    const QString testQml = QString::fromUtf8(SOURCE_DIR) + QStringLiteral("/test.qml");
    engine.load(QUrl::fromLocalFile(testQml));

    if (engine.rootObjects().isEmpty()) {
        qWarning() << "Failed to load" << testQml;
        return 1;
    }

    return app.exec();
}
