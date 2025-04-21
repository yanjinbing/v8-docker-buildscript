############################################################
# Dockerfile to build V8  container images
# Based on Ubuntu
############################################################
# Set the base image to Ubuntu
FROM ubuntu:22.04
# File Author / Maintainer
MAINTAINER Example prmis@microsoft.com
################## BEGIN INSTALLATION ######################
## 设置时区，防止卡在交互界面
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 设置环境变量以避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
# 预配置键盘设置
RUN echo "keyboard-configuration keyboard-configuration/layoutcode select us" | debconf-set-selections

# 安装 tzdata 并配置时区
RUN apt-get update && \
    apt-get install -y --no-install-recommends tzdata && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*


# Update Image
RUN apt-get update
RUN apt-get install -y sudo
RUN apt-get install -y apt-utils

RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo
RUN echo "docker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
user docker
# Update depedency of V8
RUN sudo apt-get install -y \
				lsb-core \
				git \
				#python \
				lbzip2 \
				curl 	\
				wget	\
				xz-utils \
				zip

RUN sudo apt-get install -y python3 python3-pip
RUN sudo ln -sf /usr/bin/python3 /usr/bin/python
RUN python --version
#RUN sudo echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
WORKDIR /home/docker
# Get depot_tool
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
ENV PATH /home/docker/depot_tools:"$PATH"
RUN echo $PATH
# Fetch V8 code
RUN fetch v8
RUN echo "target_os= ['android']">>.gclient
RUN gclient sync
#RUN sudo echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
# Update V8 depedency
RUN echo y | sudo /home/docker/v8/build/install-build-deps.sh
WORKDIR /home/docker/v8
ARG CACHEBUST=1
# checkout required V8 Tags
#RUN git checkout 13.7.118
RUN gclient sync
#ARG CACHEBUST=1



# ARM64
RUN python ./tools/dev/v8gen.py arm64.release -vv
RUN rm  out.gn/arm64.release/args.gn
COPY ./args_arm64.gn out.gn/arm64.release/args.gn
RUN ls -al out.gn/arm64.release/
RUN cat out.gn/arm64.release/args.gn
RUN sudo chmod 777 out.gn/arm64.release/args.gn
RUN touch out.gn/arm64.release/args.gn
RUN ninja -C out.gn/arm64.release -t clean
RUN ninja -C out.gn/arm64.release
# Prepare files for archiving
RUN rm -rf target/arm64-v8a
RUN mkdir -p target/arm64-v8a target/symbols/arm64-v8a
RUN cp -rf out.gn/arm64.release/*.so ./target/arm64-v8a
RUN cp -rf out.gn/arm64.release/lib.unstripped/*.so ./target/symbols/arm64-v8a

# ARM
# RUN python ./tools/dev/v8gen.py arm.release -vv
# RUN rm  out.gn/arm.release/args.gn
# COPY ./args_arm.gn out.gn/arm.release/args.gn
# RUN ls -al out.gn/arm.release/
# RUN cat out.gn/arm.release/args.gn
# RUN sudo chmod 777 out.gn/arm.release/args.gn
# RUN touch out.gn/arm.release/args.gn
# # Build the V8 liblary
# RUN ninja -C out.gn/arm.release -t clean
# RUN ninja -C out.gn/arm.release
# # Prepare files for archiving
# RUN rm -rf target/armeabi-v7a target/symbols/armeabi-v7a
# RUN mkdir -p target/armeabi-v7a target/symbols/armeabi-v7a
# RUN cp -rf out.gn/arm.release/*.so ./target/armeabi-v7a
# RUN cp -rf out.gn/arm.release/lib.unstripped/*.so ./target/symbols/armeabi-v7a

# X86_64
RUN python ./tools/dev/v8gen.py x64.release -vv
RUN rm out.gn/x64.release/args.gn
COPY ./args_x86_64.gn out.gn/x64.release/args.gn
RUN ls -al out.gn/x64.release/
RUN cat out.gn/x64.release/args.gn
RUN sudo chmod 777 out.gn/x64.release/args.gn
RUN touch out.gn/x64.release/args.gn
# Build the V8 liblary
RUN ninja -C out.gn/x64.release -t clean 
RUN ninja -C out.gn/x64.release
# Prepare files for archiving
RUN rm -rf target/x86_64
RUN mkdir -p target/x86_64 target/symbols/x86_64
RUN cp -rf out.gn/x64.release/*.so ./target/x86_64
RUN cp -rf out.gn/x64.release/lib.unstripped/*.so ./target/symbols/x86_64

# X86
# RUN python ./tools/dev/v8gen.py ia32.release -vv
# RUN rm out.gn/ia32.release/args.gn
# COPY ./args_x86.gn out.gn/ia32.release/args.gn
# RUN ls -al out.gn/ia32.release/
# RUN cat out.gn/ia32.release/args.gn
# RUN sudo chmod 777 out.gn/ia32.release/args.gn
# RUN touch out.gn/ia32.release/args.gn
# # Build the V8 liblary
# RUN ninja -C out.gn/ia32.release -t clean 
# RUN ninja -C out.gn/ia32.release
# # Prepare files for archiving
# RUN rm -rf target/x86
# RUN mkdir -p target/x86 target/symbols/x86
# RUN cp -rf out.gn/ia32.release/*.so ./target/x86
# RUN cp -rf out.gn/ia32.release/lib.unstripped/*.so ./target/symbols/x86

# Creating release archive
RUN mkdir ./target/headers
RUN cp -rf include ./target/headers

# We don't need testing lib in resulting package 
RUN find target -name "libv8_for_testing.cr.so" -delete

# stl lib from android-ndk have no symbols, so why bother copy them?
RUN find target/symbols -name "libc++_shared.so" -delete

# some V8 versions copy stl to release folder, some not. We need exact version of stl V8 built with to be on the safe side.
RUN cp ./third_party/android_ndk/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so ./target/arm64-v8a/
RUN cp ./third_party/android_ndk/sources/cxx-stl/llvm-libc++/libs/armeabi-v7a/libc++_shared.so ./target/armeabi-v7a
RUN cp ./third_party/android_ndk/sources/cxx-stl/llvm-libc++/libs/x86/libc++_shared.so ./target/x86/
RUN cp ./third_party/android_ndk/sources/cxx-stl/llvm-libc++/libs/x86_64/libc++_shared.so ./target/x86_64/

WORKDIR /home/docker/v8/target/
RUN zip -r ../v8.zip ./*
RUN ls -al /home/docker/v8/v8.zip
#End of docker Command

