#!/bin/sh

set -e

rootfs_url=https://cdimage.ubuntu.com/ubuntu-base/releases/mantic/release/ubuntu-base-23.10-base-amd64.tar.gz

rootfs_1=rootfs_1
[ -d "$rootfs_1" ] || {
	mkdir "$rootfs_1"
	curl "$rootfs_url" | tar -xzC "$rootfs_1"

	rm -fr "$rootfs_2"
}

rootfs_2=rootfs_2
[ -d "$rootfs_2" ] || {
	cp -r "$rootfs_1" "$rootfs_2"

	mount -B "$rootfs_2" "$rootfs_2"
	{
		mount -B /dev "$rootfs_2"/dev
		mount -B /etc/resolv.conf "$rootfs_2"/etc/resolv.conf
		mount -t tmpfs tmpfs "$rootfs_2"/tmp

		cat >"$rootfs_2"/etc/kernel/postinst.d/zz-uki <<'EOF'
#!/bin/sh

set -e

cmdline="$(mktemp)"
echo -n 'root=PARTLABEL=root rw' > "$cmdline"
{
  mkdir -p /boot/efi/EFI/boot
  objcopy \
    --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 \
    --add-section .cmdline="$cmdline" --change-section-vma .cmdline=0x30000 \
    --add-section .linux="$2" --change-section-vma .linux=0x40000 \
    --add-section .initrd=/boot/initrd.img-"$1" --change-section-vma .initrd=0x1000000 \
    /usr/lib/systemd/boot/efi/linuxx64.efi.stub \
    /boot/efi/EFI/boot/bootx64.efi
} || rm "$cmdline"
EOF
		chmod +x "$rootfs_2"/etc/kernel/postinst.d/zz-uki

		chroot "$rootfs_2" apt-get update
		chroot "$rootfs_2" apt-get --no-install-recommends -y install \
			binutils \
			initramfs-tools \
			linux-image-generic \
			systemd-boot-efi
		chroot "$rootfs_2" apt-get clean
		rm -fr "$rootfs_2"/var/lib/apt/lists/*

		umount -R "$rootfs_2"
	} || umount -R "$rootfs_2"
}

rootfs_tar_gz=rootfs.tar.gz
[ -f "$rootfs_tar_gz" ] || {
	cd "$rootfs_2"
	{
		find -maxdepth 1 -mindepth 1 | tar -czT - -f "$OLDPWD"/"$rootfs_tar_gz"

		cd "$OLDPWD"
	} || cd "$OLDPWD"
}
