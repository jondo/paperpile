#include <QNetworkAccessManager>
#include <QMap>

class RuntimeNetworkAccessManager : public QNetworkAccessManager{
    Q_OBJECT
public:
    explicit RuntimeNetworkAccessManager( QObject *parent = 0 );
    QString plackDir; 

protected:
    QNetworkReply *createRequest( Operation op,
                                  const QNetworkRequest &req,
                                  QIODevice *outgoingData );

};

