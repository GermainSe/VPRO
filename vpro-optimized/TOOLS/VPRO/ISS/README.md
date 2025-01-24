# Vektorprocessor Instruction Set Simulator (ISS)

- example application in `apps` folder
- iss library files (C-Code) in `iss_lib` folder
- vpro function definitions (implemented by hardware or ISS) library in `common_lib` folder

# Versioning

###### VPRO 1.0 [12.09.2023 + bugfixes]
- vpro1.0 (default branch)
- vpro1.0_dev (working branch for small changes/fixes)

###### Development
- dev

###### future
- vpro2.0, ...

###### outdated
- master/main

# Documentation

ISS API (Simulator Classes)
1. go into iss_lib/doc
2. run ``make``

-> https://theoretische-informatik.gitlab-pages.rz.tu-bs.de/ti/zuse-ki-avf/iss

VPRO Library:
1. run ``make -C common_lib/doc``
2. open in browser: `common_lib/doc/html/index.html`

# Compile: VPRO Library

## Compile in Standalone or for external Hardware
In Makefile this is done when using the example apps:
* ISS_STANDALONE

## Compile ISS to shared library for Virtual Prototype:
1. Go to toplevel ISS
2. issue ``make iss ``
