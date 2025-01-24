//
// Created by gesper on 27.06.19.
//

#ifndef VPRO_TUTORIAL_CPP_VECTORMAIN_H
#define VPRO_TUTORIAL_CPP_VECTORMAIN_H

#include <QDebug>
#include <QObject>

class VectorMain : public QObject {
    Q_OBJECT
   public:
    VectorMain(int (*main_fkt)(int, char**), int& argc, char** argv);

    std::atomic<bool> run_iss_thread{true};

   private:
    int& argc;
    char** argv;
    int (*main_fkt)(int, char**);

   public slots:
    int doWork();
    void exitIssThread(){
        run_iss_thread = false;
    }
};

#endif  //VPRO_TUTORIAL_CPP_VECTORMAIN_H
