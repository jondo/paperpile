#include <QtGui>

class RuntimeView;
class Runtime;

class MainWindow : public QMainWindow{
    Q_OBJECT

public:
    MainWindow();

protected:
    void closeEvent(QCloseEvent *event);

private:
    RuntimeView *view;
    Runtime* runtime;

private slots:
    void exportRuntime();
    
};
