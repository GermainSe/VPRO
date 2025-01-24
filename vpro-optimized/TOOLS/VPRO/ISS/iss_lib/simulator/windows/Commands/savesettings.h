#ifndef SAVESETTINGS_H
#define SAVESETTINGS_H

#include <QCheckBox>
#include <QDebug>
#include <QDir>
#include <QLineEdit>
#include <QList>
#include <QSettings>
#include <QVector>
#include <QWidget>

void savesettings(
    QVector<QLineEdit*> offsets, QVector<QLineEdit*> sizes, QList<QCheckBox*> checkedtorestore);

void restoresettings(
    QVector<QLineEdit*> offsets, QVector<QLineEdit*> sizes, QList<QCheckBox*> checkedtorestore);

#endif  // SAVESETTINGS_H
