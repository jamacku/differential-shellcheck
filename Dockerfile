FROM fedora:36

RUN dnf -y update \
    && dnf -y install git ShellCheck \
    && sudo dnf install -y dnf-plugins-core \
    && sudo dnf copr enable -y packit/csutils-csdiff-77 \
    && sudo dnf install -y python3-csdiff-2.6.0.20220823.123456.g064f632.pr_77-None.fc36.x86_64 csdiff-2.6.0.20220823.123456.g064f632.pr_77-None.fc36.x86_64 python3-csdiff-debuginfo-2.6.0.20220823.123456.g064f632.pr_77-None.fc36.x86_64 csdiff-debuginfo-2.6.0.20220823.123456.g064f632.pr_77-None.fc36.x86_64 csdiff-debugsource-2.6.0.20220823.123456.g064f632.pr_77-None.fc36.x86_64 \
    && dnf clean all

RUN mkdir -p /action
WORKDIR /action

COPY src/index.sh src/functions.sh ./

ENTRYPOINT ["/action/index.sh"]
