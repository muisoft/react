FROM anapsix/alpine-java:latest

WORKDIR /repo

RUN apk add --update git nodejs yarn 
RUN git clone --depth 1 -b ${BRANCH_NAME} --single-branch ${REPO_URL} .
RUN yarn 
RUN yarn build dom,core,interaction,simple-cache-provider --type=NODE 

FROM node:8-alpine

RUN apk add --update wget git && \
	mkdir /lib64 && ln -s /lib/libc.musl-x86_64.so.1 /lib64/ld-linux-x86-64.so.2 && \
  mkdir -p /tmp/gotty && cd /tmp/gotty && \
	wget https://github.com/yudai/gotty/releases/download/v1.0.1/gotty_linux_amd64.tar.gz && \
	tar -zxvf gotty_linux_amd64.tar.gz && \
	mv gotty /usr/local/bin/gotty && \
	rm -rf /tmp/gotty /var/cache/apk/*

RUN echo $'\
preferences {\n\
	background_color = "#222"\n\
	scrollbar_visible = false\n\
	// [string] URL of user stylesheet to include in the terminal document.\n\
	user_css = ""\n\
}' > ~/.gotty

EXPOSE 8080
ARG BRANCH_NAME=master
ARG REPO_URL=https://github.com/forkboxlabs/react

COPY --from=0 /repo/build/node_modules /repo/build/node_modules
COPY --from=0 /repo/fixtures/unstable-async/suspense /repo/fixtures/unstable-async/suspense

WORKDIR /repo

RUN yarn --cwd fixtures/unstable-async/suspense

ENV FORKBOX_COMMAND TERMINAL

RUN echo $'\
#!/bin/bash \n\
git pull \n\
echo "FORKBOX_COMMAND has the value: $FORKBOX_COMMAND" \n\
case "$FORKBOX_COMMAND" in \n\
TERMINAL) gotty --permit-write --reconnect --title-format "ForkBox Terminal" /bin/sh ;; \n\
TESTS) gotty --permit-write --reconnect yarn test:watch ;; \n\ 
SUSPENSE) cd fixtures/unstable-async/suspense/ && yarn start ;; \n\ 
*) gotty --permit-write --reconnect --title-format "ForkBox Terminal" /bin/sh ;; \n\
esac \n\
' > ~/start.sh && chmod +x ~/start.sh

CMD (watch -n 3 git pull &>/dev/null &) && ~/start.sh
