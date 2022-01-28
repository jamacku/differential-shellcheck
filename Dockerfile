
FROM fedora:rawhide

RUN dnf -y update
RUN dnf -y install csdiff ShellCheck

RUN mkdir -p /action
WORKDIR /action

COPY .github/exception-list.txt .github/script-list.txt ./
COPY src/check-shell.sh src/functions.sh ./

ENTRYPOINT ["/action/check-shell.sh"]