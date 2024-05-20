---
layout: 'post'
title: 'GNU Guix: Setup a channel'
date: '2024-03-30 14:00:00'
categories: ['Guix' ]
tags: ['guix', 'gnu', 'functional', 'scheme', 'guile'] 
---

* [Creating a Channel](https://guix.gnu.org/en/manual/devel/en/guix.html#Creating-a-Channel)



* [Package Modules in a Sub-directory](https://guix.gnu.org/en/manual/devel/en/guix.html#Package-Modules-in-a-Sub_002ddirectory)
```scheme
(channel
 (version 0)
 (directory "homebrew")
 (url "https://codeberg.org/zie87/guix-homebrew"))
```
{: file=".guix-channel" }

```bash
gpg --export -a --output tobias.key tobias.zindl@googlemail.com
gpg --armor --export DA7EFDB0EF799E04
gpg --armor --export DA7EFDB0EF799E04 > zie87-EF799E04.key
gpg --list-secret-keys --keyid-format=long
gpg --list-secret-keys --keyid-format=long --with-fingerprint 
```

* [Specifying Channel Authorizations](https://guix.gnu.org/en/manual/devel/en/guix.html#Specifying-Channel-Authorizations)

```scheme
(authorizations
 (version 0)
 (("B465 5185 3F34 E63B B9F6  51E3 DA7E FDB0 EF79 9E04"
   (name "zie87"))))
```
{: file=".guix-authorizations" }

* [`guix git authenticate`](https://guix.gnu.org/en/manual/devel/en/guix.html#Invoking-guix-git-authenticate)

## References

### Blogs

* guix: [Authenticate your Git checkouts!](https://guix.gnu.org/en/blog/2024/authenticate-your-git-checkouts)
* aalonso: [GPG + Git basics: How to generate keys, sign commits, and export keys to another machine](https://aalonso.dev/blog/2022/how-to-generate-gpg-keys-sign-commits-and-export-keys-to-another-machine)

## Footnotes

