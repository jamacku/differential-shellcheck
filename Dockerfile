
FROM fedora

RUN dnf -y update
RUN dnf -y install csdiff shellcheck

RUN mkdir -p /action
WORKDIR /action

COPY .github/exception-list.txt .github/script-list.txt ./
COPY src/check-shell.sh src/functions.sh ./

ENTRYPOINT ["./check-shell.sh"]