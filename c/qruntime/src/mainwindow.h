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
    bool isDebugMode();

private slots:
    void exportRuntime();
    
};
