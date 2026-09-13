include $(TOPDIR)/rules.mk

PKG_NAME:=happwrt
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=happwrt

include $(INCLUDE_DIR)/package.mk

define Package/happwrt
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=Happ-compatible subscription client for sing-box
	URL:=https://github.com/
	DEPENDS:=+ucode +ucode-mod-fs +ucode-mod-uci +curl +uclient-fetch +ca-bundle +sing-box-tiny
	PKGARCH:=all
endef

define Package/happwrt/description
 Subscription client for OpenWrt routers. Downloads a Happ compatible
 subscription, converts the share links (VLESS, VMess, Trojan, Shadowsocks,
 Hysteria2, TUIC, AnyTLS) into a sing-box configuration and runs it as a
 transparent split-tunnel proxy gateway.
endef

define Package/happwrt/conffiles
/etc/config/happwrt
endef

define Package/happwrt/install
	$(INSTALL_DIR) $(1)/usr/share/happwrt
	$(INSTALL_DATA) ./files/usr/share/happwrt/parse.uc $(1)/usr/share/happwrt/parse.uc
	$(INSTALL_DATA) ./files/usr/share/happwrt/gen.uc $(1)/usr/share/happwrt/gen.uc
	$(INSTALL_DATA) ./files/usr/share/happwrt/opts.uc $(1)/usr/share/happwrt/opts.uc
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/happwrt $(1)/usr/bin/happwrt
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/happwrt $(1)/etc/init.d/happwrt
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/happwrt $(1)/etc/config/happwrt
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/etc/uci-defaults/90-happwrt $(1)/etc/uci-defaults/90-happwrt
endef

define Package/happwrt/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/happwrt enable >/dev/null 2>&1
exit 0
endef

define Package/happwrt/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/happwrt stop >/dev/null 2>&1
exit 0
endef

define Build/Compile
endef

$(eval $(call BuildPackage,happwrt))
