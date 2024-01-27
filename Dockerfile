FROM public.ecr.aws/lambda/ruby:3.2

ARG USERNAME=rubygems-builder
ARG GROUPNAME=rubygems-builder
ARG UID=1000
ARG GID=1000

RUN yum update -y

# Create a user for building RubyGems
RUN yum install -y shadow-utils

RUN /usr/sbin/groupadd --gid $GID $GROUPNAME
RUN /usr/sbin/useradd --uid $UID --gid $GID --create-home --shell /bin/bash $USERNAME
RUN mkdir /home/$USERNAME/lambda-layer

# Install additionally required libraries for building RubyGems
RUN yum groupinstall -y "Development Tools"
# RUN yum install -y <some required libraries for building RubyGems>

USER $USERNAME

ENTRYPOINT ["/bin/bash"] # Overwrites the ENTRYPOINT of public.ecr.aws/lambda/ruby:3.2
