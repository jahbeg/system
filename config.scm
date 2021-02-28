(define-module (my packages)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  ;#:use-module (gnu packages web)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages display-managers)
  #:use-module (guix build-system trivial)
  #:use-module (gnu)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (gnu services docker)
  #:use-module (gnu services desktop)
  #:use-module (srfi srfi-1))

(define (linux-nonfree-urls version)
  "Return a list of URLs for Linux-Nonfree VERSION."
  (list (string-append
         "https://www.kernel.org/pub/linux/kernel/v5.x/"
         "linux-" version ".tar.xz")))

;; Remove this and native-inputs below to use the default config from Guix.
;; Make sure the kernel minor version matches, though.
(define kernel-config
  (string-append (dirname (current-filename)) "/kernel.config"))

(define-public linux-nonfree
  (let* ((version "5.4.15"))
    (package
      (inherit linux-libre)
      (name "linux-nonfree")
      (version version)
      (source (origin
                (method url-fetch)
                (uri (linux-nonfree-urls version))
                (sha256
                 (base32
                  "1ccldlwj89qd22cl06706w7xzm8n69m6kg8ic0s5ns0ghlpj41v4"))))
      (synopsis "Mainline Linux kernel, nonfree binary blobs included.")
      (description "Linux is a kernel.")
      (license license:gpl2)
      (home-page "http://kernel.org/"))))

(define-public linux-firmware-non-free
  (package
    (name "linux-firmware-non-free")
    (version "1eb2408c6feacccd10b02a49214745f15d1c6fb7")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "0256p99bqwf1d1s6gqnzpjcdmg6skcp1jzz64sd1p29xxrf0pzfa"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/")))
                     (mkdir-p fw-dir)
                     (copy-recursively source fw-dir)
                     #t))))
    (home-page "")
    (synopsis "Non-free firmware for Linux")
    (description "Non-free firmware for Linux")
    ;; FIXME: What license?
    (license (license:non-copyleft "http://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git;a=blob_plain;f=LICENCE.radeon_firmware;hb=HEAD"))))

(define-public iwlwifi-firmware-nonfree
  (package
    (name "iwlwifi-firmware-nonfree")
    (version "65b1c68c63f974d72610db38dfae49861117cae2")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "1anr7fblxfcrfrrgq98kzy64yrwygc2wdgi47skdmjxhi3wbrvxz"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/")))
                     (mkdir-p fw-dir)
                     (for-each (lambda (file)
                                 (copy-file file
                                            (string-append fw-dir (basename file))))
                               (find-files source
                                           "iwlwifi-.*\\.ucode$|LICENSE\\.iwlwifi_firmware$"))
                     #t))))
    (home-page "https://wireless.wiki.kernel.org/en/users/drivers/iwlwifi")
    (synopsis "Non-free firmware for Intel wifi chips")
    (description "Non-free iwlwifi firmware")
    (license (license:non-copyleft
              "https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/tree/LICENCE.iwlwifi_firmware?id=HEAD"))))

(define-public ibt-hw-firmware-nonfree
  (package
    (name "ibt-hw-firmware-nonfree")
    (version "c883a6b6186bb2415761d287cbac773062911212")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
                    (commit version)))
              (sha256
               (base32
                "1a8s17w1l4vml069lc2dwmlspd38021ij1y8gzwl24r6giv5hnzj"))))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder (begin
                   (use-modules (guix build utils))
                   (let ((source (assoc-ref %build-inputs "source"))
                         (fw-dir (string-append %output "/lib/firmware/intel")))
                     (mkdir-p fw-dir)
                     (for-each (lambda (file)
                                 (copy-file file
                                            (string-append fw-dir "/"
                                                           (basename file))))
                               (find-files source "ibt-hw-.*\\.bseq$|LICENCE\\.ibt_firmware$"))
                     #t))))

    (home-page "http://www.intel.com/support/wireless/wlan/sb/CS-016675.htm")
    (synopsis "Non-free firmware for Intel bluetooth chips")
    (description "Non-free firmware for Intel bluetooth chips")
    ;; FIXME: What license?
    (license (license:non-copyleft "http://git.kernel.org/?p=linux/kernel/git/firmware/linux-firmware.git;a=blob_plain;f=LICENCE.ibt_firmware;hb=HEAD"))))


(define %sysctl-activation-service
  (simple-service 'sysctl activation-service-type
		  #~(let ((sysctl
			   (lambda (str)
			     (zero? (apply system*
					   #$(file-append procps
							  "/sbin/sysctl")
					   "-w" (string-tokenize str))))))
		      (and
		       ;; Enable IPv6 privacy extensions.
		       (sysctl "net.ipv6.conf.eth0.use_tempaddr=2")
		       ;; Enable SYN cookie protection.
		       (sysctl "net.ipv4.tcp_syncookies=1")
		       ;; Log Martian packets.
		       (sysctl "net.ipv4.conf.default.log_martians=1")))))

(define %powertop-service
  (simple-service 'powertop activation-service-type
		  #~(zero? (system* #$(file-append powertop "/sbin/powertop")
				    "--auto-tune"))))

(use-modules (gnu)
             (guix store)               ;for %default-substitute-urls
             (gnu system nss)
             (my packages)
             (srfi srfi-1))
(use-service-modules admin base dbus desktop mcron networking ssh xorg sddm)
(use-package-modules admin bootloaders certs disk fonts file emacs
                     libusb linux version-control
                     ssh tls tmux wm xdisorg xorg)

(operating-system
  (host-name "gazelle")
  (timezone "Europe/Paris")
  (keyboard-layout (keyboard-layout "us" "intl" #:options '("ctrl:nocaps" "compose:menu")))
  (kernel linux-nonfree)
  (kernel-arguments '("modprobe.blacklist=pcspkr,snd_pcsp,nouveau"))
  ;; (locale "en_GB.utf8")
  ;; (locale-libcs (list glibc-2.24 (canonical-package glibc)))
  (firmware (append (list
                     ibt-hw-firmware-nonfree
                     iwlwifi-firmware-nonfree)
                    %base-firmware))

  (bootloader (bootloader-configuration
               (bootloader grub-efi-bootloader)
               (target "/boot/efi")
               (keyboard-layout keyboard-layout)))

  ;; Specify mapped devices
  ;(mapped-devices
   ;(lmst (mapped-device
          ;(source (uuid "04cfc415-34f1-48bc-a138-24201cd069fb"))
          ;(target "home")
          ;(type luks-device-mapping))

         ;(mapped-device
          ;(source (uuid "aa0738ab-7b39-4429-92cd-c02dddc7871b"))
          ;(target "elephant")
          ;(type luks-device-mapping))))

  (file-systems (cons* (file-system
                         (device (file-system-label "guixroot"))
                         (mount-point "/")
                         (needed-for-boot? #t)
                         (type "ext4"))

                       ;(file-system
                         ;(device "/dev/mapper/home")
                         ;(mount-point "/home")
                         ;(type "ext4"))

                       ;(file-system
                         ;(device "/dev/mapper/elephant")
                         ;(mount-point "/mnt/elephant")
                         ;(type "ext4"))

                       (file-system
                         (device "/dev/nvme0n1p1")
                         (mount-point "/boot/efi")
                         (type "vfat"))

                       %base-file-systems))

  (swap-devices (list "/swapfile"))

  (groups (cons (user-group
                 (name "bambata"))
                %base-groups))

  (users (cons (user-account
                (name "bambata")
                (comment "Meeh")
                (group "bambata")
                (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "disk"))
                (home-directory "/home/bambata"))
               %base-user-accounts))

  (packages (cons*
             dosfstools
             nss-certs
             htop
             wpa-supplicant
             acpid
             ;i3-wm
             ;i3status
             ;xscreensaver
             ;nitrogen
             ;vim
             ;tmux
             ;docker
             ;vlc
             ;jq
             ;json-modern-cxx
             %base-packages))

  (services (cons*
             (service sddm-service-type)
             (screen-locker-service xscreensaver)
             (service wpa-supplicant-service-type)
             (service network-manager-service-type)
             (service upower-service-type)
             (service colord-service-type)
             (geoclue-service)
             (polkit-service)
             (elogind-service)
             (dbus-service)
             ;(service rottlog-service-type)
             (service mcron-service-type)
             (service docker-service-type)

             %desktop-services
             %sysctl-activation-service
             %powertop-service

             ;; Add udev rules for MTP devices so that non-root users can access
             ;; them.
             (simple-service 'mtp udev-service-type (list libmtp)))))

             ;; Store the current configuration with the generation.
             ;(simple-service 'store-my-config
                             ;etc-service-type
                             ;`(("current-config.scm"
                                ;,(local-file (assoc-ref
                                              ;(current-source-location)
                                              ;'filename))))))))

             ;(service ntp-service-type)
             ;(modify-services %base-services
               ;(guix-service-type
                ;config =>
                ;(guix-configuration
                 ;(inherit config)
                 ;(substitute-urls
                  ;(cons* "http://192.168.2.11:8181"
                         ;"http://192.168.2.5:3000"
                         ;"http://137.205.52.16"
                         ;%default-substitute-urls)))))))
