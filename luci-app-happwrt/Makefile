include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-happwrt
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=happwrt

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-happwrt
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=HappWRT subscription client
	DEPENDS:=+luci-base +happwrt
	PKGARCH:=all
endef

define Package/luci-app-happwrt/description
 LuCI interface for the HappWRT subscription client.
endef

define Package/luci-app-happwrt/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/happwrt
	$(INSTALL_DATA) ./htdocs/luci-static/resources/view/happwrt/main.js $(1)/www/luci-static/resources/view/happwrt/main.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-happwrt.json $(1)/usr/share/luci/menu.d/luci-app-happwrt.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-happwrt.json $(1)/usr/share/rpcd/acl.d/luci-app-happwrt.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/ucode
	$(INSTALL_DATA) ./root/usr/share/rpcd/ucode/luci.happwrt.uc $(1)/usr/share/rpcd/ucode/luci.happwrt.uc
endef

define Package/luci-app-happwrt/postinst
#!/bin/sh
rm -f /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null
exit 0
endef

define Build/Compile
endef

$(eval $(call BuildPackage,luci-app-happwrt))
