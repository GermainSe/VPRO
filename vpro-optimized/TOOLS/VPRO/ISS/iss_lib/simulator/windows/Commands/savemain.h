#ifndef SAVEMAIN_H
#define SAVEMAIN_H

#include <QDebug>
#include <QFile>
#include <QFileDevice>
#include <QFileDialog>
#include <QLineEdit>
#include <QMainWindow>
#include <QMessageBox>
#include <QObject>
#include <QVector>
#include <QWidget>
#pragma once
class CommandWindow;
#include "commandwindow.h"

void savemaintofile(int i,
    CommandWindow* Widget,
    QVector<QLineEdit*> offsets,
    QVector<QLineEdit*> sizes,
    bool* paused);
#endif  // SAVEMAIN_H
