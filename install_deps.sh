/bin/sh
wget -qO- https://get.docker.com/ | sh
apt-get install \
    poppler-utils \
    ghostscript \
    qpdf \
    --yes
npm rebuild
