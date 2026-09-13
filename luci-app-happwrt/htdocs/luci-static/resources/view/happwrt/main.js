'use strict';
'require view';
'require form';
'require rpc';
'require uci';
'require ui';

var callStatus = rpc.declare({
	object: 'luci.happwrt',
	method: 'status',
	expect: {}
});

var callUpdate = rpc.declare({
	object: 'luci.happwrt',
	method: 'update',
	expect: {}
});

var callReload = rpc.declare({
	object: 'luci.happwrt',
	method: 'reload',
	expect: {}
});

function statusText(st) {
	if (!st)
		return _('Unavailable');

	var parts = [];

	parts.push(st.enabled ? _('Enabled') : _('Disabled'));
	parts.push(st.running ? _('running') : _('stopped'));
	parts.push(_('Servers') + ': ' + (st.node_count || 0));

	return parts.join(' | ');
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('happwrt'),
			callStatus()
		]);
	},

	render: function (data) {
		var status = data[1];
		var m, s, o;

		m = new form.Map('happwrt', _('HappWRT'),
			_('Happ compatible subscription client based on sing-box. Split tunneling gateway with a TUN interface.'));

		s = m.section(form.NamedSection, 'main', 'happwrt');
		s.anonymous = true;

		o = s.option(form.DummyValue, '_status', _('Status'));
		o.cfgvalue = function () {
			return statusText(status);
		};

		o = s.option(form.Flag, 'enabled', _('Enable'),
			_('Start sing-box and route traffic through the proxy.'));
		o.rmempty = false;
		o.default = '0';

		o = s.option(form.Value, 'subscription_url', _('Subscription URL'),
			_('Happ / v2ray subscription link.'));
		o.datatype = 'string';
		o.rmempty = true;

		o = s.option(form.ListValue, 'proxy_mode', _('Routing mode'));
		o.value('bypass_ru', _('Proxy all except Russia (RU direct)'));
		o.value('rules_only', _('Proxy only the listed domains and IPs'));
		o.value('global', _('Proxy everything'));
		o.default = 'bypass_ru';
		o.rmempty = false;

		o = s.option(form.ListValue, 'selected_node', _('Server'));
		o.value('', _('Auto (url-test fastest)'));
		(status && status.nodes ? status.nodes : []).forEach(function (n) {
			o.value(n.tag, n.name || n.tag);
		});
		o.default = '';

		o = s.option(form.Value, 'update_interval', _('Update interval'),
			_('Hours between automatic subscription updates.'));
		o.datatype = 'uinteger';
		o.default = '24';
		o.rmempty = true;

		o = s.option(form.Value, 'dns_direct', _('Direct DNS'), _('Resolver used for direct traffic.'));
		o.datatype = 'ipaddr';
		o.default = '77.88.8.8';
		o.rmempty = true;

		o = s.option(form.Value, 'dns_proxy', _('Proxy DNS'), _('Resolver used for proxied traffic.'));
		o.datatype = 'ipaddr';
		o.default = '1.1.1.1';
		o.rmempty = true;

		o = s.option(form.ListValue, 'dns_strategy', _('DNS strategy'));
		o.value('ipv4_only', _('IPv4 only'));
		o.value('prefer_ipv4', _('Prefer IPv4'));
		o.value('ipv6_only', _('IPv6 only'));
		o.value('prefer_ipv6', _('Prefer IPv6'));
		o.default = 'ipv4_only';

		o = s.option(form.ListValue, 'tun_stack', _('TUN stack'));
		o.value('gvisor', _('gVisor'));
		o.value('system', _('System'));
		o.value('mixed', _('Mixed'));
		o.default = 'gvisor';

		o = s.option(form.Value, 'wan_interface', _('WAN interface'),
			_('Optional. Bind outgoing connections to this interface (e.g. wan). Leave empty for auto-detection.'));
		o.datatype = 'string';
		o.rmempty = true;

		o = s.option(form.ListValue, 'log_level', _('Log level'));
		o.value('error', 'error');
		o.value('warn', 'warn');
		o.value('info', 'info');
		o.value('debug', 'debug');
		o.value('trace', 'trace');
		o.default = 'warn';

		o = s.option(form.Flag, 'ad_block', _('Block ads'),
			_('Reject domains from the sing-box ads rule-set.'));

		o = s.option(form.Flag, 'clash_api', _('Clash API'),
			_('Enable the local Clash API for statistics and mode switching.'));

		o = s.option(form.DynamicList, 'custom_proxy_domains', _('Always proxy domains'),
			_('Domain suffixes routed through the proxy in every mode.'));
		o.datatype = 'string';

		o = s.option(form.DynamicList, 'custom_direct_domains', _('Always direct domains'),
			_('Domain suffixes routed directly in every mode.'));
		o.datatype = 'string';

		o = s.option(form.DynamicList, 'custom_proxy_cidrs', _('Always proxy IPs'),
			_('IP addresses or CIDR subnets routed through the proxy.'));
		o.datatype = 'string';

		o = s.option(form.DynamicList, 'custom_direct_cidrs', _('Always direct IPs'),
			_('IP addresses or CIDR subnets routed directly.'));
		o.datatype = 'string';

		o = s.option(form.Value, 'rule_set_base', _('Rule-set base URL'),
			_('Base URL for sing-box geoip/geosite rule-sets. Change it to a mirror if raw.githubusercontent.com is blocked.'));
		o.datatype = 'string';
		o.default = 'https://raw.githubusercontent.com';
		o.rmempty = true;

		o = s.option(form.Button, '_update', _('Subscription'));
		o.inputtitle = _('Update now');
		o.inputstyle = 'apply';
		o.onclick = function () {
			return uci.save()
				.then(function () { return callUpdate(); })
				.then(function (res) {
					ui.addNotification(null,
						E('pre', { style: 'white-space: pre-wrap' }, (res && res.output) || ''),
						'info');
					window.location.reload();
				});
		};

		o = s.option(form.Button, '_reload', _('Configuration'));
		o.inputtitle = _('Apply and restart');
		o.inputstyle = 'apply';
		o.onclick = function () {
			return uci.save()
				.then(function () { return callReload(); })
				.then(function () {
					window.location.reload();
				});
		};

		return m.render();
	}
});
