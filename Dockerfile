FROM alpine:latest AS font-builder

RUN apk --update add msttcorefonts-installer \
      && rm -rf /var/cache/apk/* \
      && update-ms-fonts

COPY ./fonts/*.ttf /fonts/truetype/astra/

FROM debian:bookworm-slim AS base

COPY --from=font-builder /fonts /usr/share/fonts/truetype/astra/
COPY --from=font-builder /usr/share/fonts/truetype/msttcorefonts /usr/share/fonts/truetype/msttcorefonts

#FROM ubuntu:22.04 AS base
#FROM debian:bookworm-slim
RUN chmod -R 644 /usr/share/fonts/truetype/astra/* /usr/share/fonts/truetype/msttcorefonts/*

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
# ------------------------------------------------------------
# System dependencies (minimal but sufficient)
# ------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        fontconfig \
        fonts-cmu \
        fonts-dejavu \
        fonts-noto-core \
        fonts-noto-extra \
        ghostscript \
        locales \
        perl \
        wget \
        xz-utils \
        && rm -rf /var/lib/apt/lists/* \
	/var/cache/apt/archives/* \
	/usr/share/doc/* \
	/usr/share/man/*

# Russian UTF-8 locale
RUN sed -i 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen && locale-gen

ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8

WORKDIR /tmp/install-tl

RUN <<EOF
wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
tar -xzf install-tl-unx.tar.gz --strip-components=1
EOF

#RUN wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
#    && tar -xzf install-tl-unx.tar.gz \
#    && cd install-tl-* \
#    printf "selected_scheme scheme-small\nTEXDIR %s\nTEXMFCONFIG ~/.texlive/texmf-config\nTEXMFVAR ~/.texlive/texmf-var\n" \
#      "$TL_INSTALL_DIR" > texlive.profile \
#    && printf "tlpdbopt_install_docfiles 0\n" >> texlive.profile \
#    && printf "tlpdbopt_install_srcfiles 0\n" >> texlive.profile \
#    && printf "tlpdbopt_autobackup 0\n" >> texlive.profile \
#    && ./install-tl -profile texlive.profile \
#    && cd / \
#    && rm -rf /tmp/install-tl-*

FROM base AS build
RUN cat <<PROFILE > texlive.profile
#selected_scheme scheme-custom
selected_scheme scheme-basic

TEXDIR /usr/local/texlive
TEXMFCONFIG ~/.texlive/texmf-config
TEXMFHOME ~/texmf
TEXMFLOCAL /usr/local/texlive/texmf-local
TEXMFSYSCONFIG /usr/local/texlive/texmf-config
TEXMFSYSVAR /usr/local/texlive/texmf-var
TEXMFVAR ~/.texlive/texmf-var

#collection-basic 1
#collection-bibtexextra 1
#collection-binextra 1
#collection-fontsextra 1
collection-fontsrecommended 1
#collection-fontutils 1
#collection-formatsextra 1
#collection-latex 1
#collection-latexextra 1
collection-latexrecommended 1
collection-luatex 1
collection-mathscience 1
#collection-metapost 1
#collection-pictures 1
#collection-plaingeneric 1
#collection-pstricks 1

instopt_adjustpath 0
instopt_adjustrepo 1
instopt_write18_restricted 1
tlpdbopt_autobackup 0
tlpdbopt_create_formats 0
tlpdbopt_desktop_integration 0
tlpdbopt_file_assocs 0
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 0
tlpdbopt_install_srcfiles 0
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/share/man
PROFILE

FROM build AS install
RUN ./install-tl -profile texlive.profile && cd .. && rm -rf install-tl

ENV PATH="/usr/local/texlive/bin/x86_64-linux:$PATH"
# ------------------------------------------------------------
# Lock tlmgr to TeX Live 2025 repository
# ------------------------------------------------------------
#RUN tlmgr option repository https://mirror.ctan.org/systems/texlive/tlnet/2025

# ------------------------------------------------------------
# Install only required collections
# ------------------------------------------------------------
RUN tlmgr install \
  latexmk
#    collection-latex \
#    collection-latexrecommended \
#    collection-latexextra \
#    collection-luatex \
#    collection-mathscience \
#    collection-pictures \
#    collection-fontsrecommended \
#    collection-langcyrillic \
#    collection-biblatex \
#    collection-bibtexextra \
#    algorithm2e \
    #latexmk \
    #biber

RUN fmtutil-sys --all && updmap-sys && fc-cache -fv
RUN luaotfload-tool --update --force --prefer-texmf

WORKDIR /work

ENTRYPOINT ["latexmk", "-lualatex", "-interaction=nonstopmode", "-halt-on-error"]
