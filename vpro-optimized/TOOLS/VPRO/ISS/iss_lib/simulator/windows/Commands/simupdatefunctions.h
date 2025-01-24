#ifndef SIMUPDATEFUNCTIONS_H
#define SIMUPDATEFUNCTIONS_H
#include <QDebug>
#include <QProgressBar>
#include <QRadioButton>
#include <QRegularExpression>
#include <QRegularExpressionMatch>
#include <QVector>

int updatelanes(QVector<QRadioButton*> radiobuttons,
    QVector<QProgressBar*> progressbars,
    long clock,
    QVector<long> clockvalues,
    QVector<double> progresstotal);  //update for the last x cycles

int updatelanestotal(QVector<QProgressBar*> progressbars, long clock);  //update for all cycles

#endif  // SIMUPDATEFUNCTIONS_H
