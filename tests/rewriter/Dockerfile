# The suite of this directory, which run.sh runs on the stack's network
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/mirrors/python-3.12.9-slim-bookworm@sha256:39eccca5adccd226907d67b828376af68599c6f5abfe1be38affbc1643616fa1
RUN pip install --no-cache-dir pytest==8.3.5
COPY . /tests
WORKDIR /tests
ENTRYPOINT ["python", "-m", "pytest", "-p", "no:cacheprovider", "-rs"]
