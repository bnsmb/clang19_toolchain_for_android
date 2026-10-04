rm git-receive-pack && \
ln -s ./git git-receive-pack 2>/dev/null || \
cp git git-receive-pack


rm git-upload-archive && \
ln -s ./git git-upload-archive 2>/dev/null || \
cp git git-upload-archive


rm git-upload-pack && \
ln -s ./git git-upload-pack 2>/dev/null || \
cp git git-upload-pack

