ARG BUILDER_IMAGE

FROM ${BUILDER_IMAGE} AS build

WORKDIR /build
COPY . .

RUN CGO_ENABLED=1 make install

FROM registry.ddbuild.io/images/nvidia-cuda-base:12.9.0

LABEL maintainers="Compute"

COPY --from=build /usr/bin/dcgm-exporter /usr/bin/
COPY etc /etc/dcgm-exporter

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    datacenter-gpu-manager-4-core datacenter-gpu-manager-4-proprietary libcap2-bin \
    && apt-get -y clean \
    && apt-get -y autoclean \
    && apt-get autoremove -y \
    && rm -rfd /usr/local/dcgm/bindings /usr/local/dcgm/sdk_samples /usr/share/nvidia-validation-suite \
    # DCGM exporter doesn't use libdcgm_cublas_proxy*.so.
    && rm -rf /usr/lib/x86_64-linux-gnu/libdcgm_cublas_proxy*.so \
    && rm -rf /usr/local/dcgm/scripts \
    && rm -f /usr/include/*.h /usr/bin/DcgmProfTesterKernels.ptx /usr/bin/dcgmproftester* \
    && rm -rf /var/cache/debconf/* /var/lib/apt/lists/* /var/log/* /tmp/* /var/tmp/* \
    && rm -rf /usr/share/doc && rm -rf /usr/share/man \
    && ldconfig
# Required for DCP metrics
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,compat32
# disable all constraints on the configurations required by NVIDIA container toolkit
ENV NVIDIA_DISABLE_REQUIRE="true"
ENV NVIDIA_VISIBLE_DEVICES=all

ENV NO_SETCAP=""
COPY docker/dcgm-exporter-entrypoint.sh /usr/local/dcgm/dcgm-exporter-entrypoint.sh
RUN chmod +x /usr/local/dcgm/dcgm-exporter-entrypoint.sh

ENTRYPOINT ["/usr/local/dcgm/dcgm-exporter-entrypoint.sh"]
