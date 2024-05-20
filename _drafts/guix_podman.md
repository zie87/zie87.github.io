---
layout: 'post'
title: 'GNU Guix: setup podman'
date: '2024-01-28 16:05:00'
categories: ['Guix' ]
tags: ['guix', 'nix', 'gnu', 'linux', 'functional', 'scheme', 'guile', 'podman', 'docker', 'container']
---



```
podman pull docker.io/zephyrprojectrtos/zephyr-build:latest
Error: open /etc/containers/policy.json: no such file or directory
```

```
WARN[0000] "/" is not a shared mount, this could cause issues or missing mounts with rootless containers 
ERRO[0000] cannot find UID/GID for user zie: open /etc/subuid: no such file or directory - check rootless mode in man pages. 
WARN[0000] Using rootless single mapping into the namespace. This might break some images. Check /etc/subuid and /etc/subgid for adding sub*ids if not using a network user 

Error: copying system image from manifest list: writing blob: adding layer with blob "sha256:29202e855b2021a2d7f92800619ed5f5e8ac402e267cfbb3d29a791feb13c1ee": ApplyLayer stdout:  stderr: potentially insufficient UIDs or GIDs available in user namespace (requested 0:42 for /etc/gshadow): Check /etc/subuid and /etc/subgid if configured locally and run podman-system-migrate: lchown /etc/gshadow: invalid argument exit status 1
```

- [reddit: Getting podman working with rootless containers](https://www.reddit.com/r/GUIX/comments/13tudtn/getting_podman_working_with_rootless_containers/)
  - [system config](https://github.com/alam0rt/guix-config/blob/main/saml/system/config.scm) 
  - [home config](https://github.com/alam0rt/guix-config/blob/main/saml/home/home-configuration.scm)

## References

### Blogs

- Goose and Quill: [Podman in Theory and Practice](https://gooseandquill.blog/posts/install-rootless-podman-on-guix.html)

## Footnotes

[1]: https://podman.io/
[2]: https://buildah.io/
