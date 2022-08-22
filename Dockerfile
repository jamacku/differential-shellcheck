FROM fedora:36

RUN dnf -y update \
    && dnf -y install git ShellCheck \
    && sudo dnf install -y dnf-plugins-core \
    && sudo dnf copr enable -y packit/csutils-csdiff-68 \
    && sudo dnf install -y csdiff-debugsource-2.6.0.20220818.105912.gdde5c9a.pr_68-None.fc36.x86_64 csdiff-debuginfo-2.6.0.20220818.105912.gdde5c9a.pr_68-None.fc36.x86_64 python3-csdiff-2.6.0.20220818.105912.gdde5c9a.pr_68-None.fc36.x86_64 python3-csdiff-debuginfo-2.6.0.20220818.105912.gdde5c9a.pr_68-None.fc36.x86_64 csdiff-2.6.0.20220818.105912.gdde5c9a.pr_68-None.fc36.x86_64 \
    && dnf clean all

RUN mkdir -p /action
WORKDIR /action

COPY src/index.sh src/functions.sh ./

ENTRYPOINT ["/action/index.sh"]
