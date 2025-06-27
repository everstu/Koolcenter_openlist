#!/bin/sh
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
MODEL=
FW_TYPE_CODE=
FW_TYPE_NAME=
DIR=$(cd $(dirname $0); pwd)
module=${DIR##*/}

get_model(){
	local ODMPID=$(nvram get odmpid)
	local PRODUCTID=$(nvram get productid)
	if [ -n "${ODMPID}" ];then
		MODEL="${ODMPID}"
	else
		MODEL="${PRODUCTID}"
	fi
}

get_fw_type() {
	local KS_TAG=$(nvram get extendno|grep -Eo "kool.+")
	if [ -d "/koolshare" ];then
		if [ -n "${KS_TAG}" ];then
			FW_TYPE_CODE="2"
			FW_TYPE_NAME="${KS_TAG}官改固件"
		else
			FW_TYPE_CODE="4"
			FW_TYPE_NAME="koolshare梅林改版固件"
		fi
	else
		if [ "$(uname -o|grep Merlin)" ];then
			FW_TYPE_CODE="3"
			FW_TYPE_NAME="梅林原版固件"
		else
			FW_TYPE_CODE="1"
			FW_TYPE_NAME="华硕官方固件"
		fi
	fi
}

platform_test(){
	local LINUX_VER=$(uname -r|awk -F"." '{print $1$2}')
	local ARCH=$(uname -m)
	if [ -d "/koolshare" -a -f "/usr/bin/skipd" -a "${LINUX_VER}" -ge "41" ];then
		echo_date 机型："${MODEL} ${FW_TYPE_NAME} 符合安装要求，开始安装插件！"
	else
		exit_install 1
	fi
}

set_skin(){
	local UI_TYPE=ASUSWRT
	local SC_SKIN=$(nvram get sc_skin)
	local ROG_FLAG=$(grep -o "680516" /www/form_style.css|head -n1)
	local TUF_FLAG=$(grep -o "D0982C" /www/form_style.css|head -n1)
	if [ -n "${ROG_FLAG}" ];then
		UI_TYPE="ROG"
	fi
	if [ -n "${TUF_FLAG}" ];then
		UI_TYPE="TUF"
	fi
	
	if [ -z "${SC_SKIN}" -o "${SC_SKIN}" != "${UI_TYPE}" ];then
		echo_date "安装${UI_TYPE}皮肤！"
		nvram set sc_skin="${UI_TYPE}"
		nvram commit
	fi
}

exit_install(){
	local state=$1
	case $state in
		1)
			echo_date "本插件适用于【koolshare 梅林改/官改 hnd/axhnd/axhnd.675x】固件平台！"
			echo_date "你的固件平台不能安装！！!"
			echo_date "本插件支持机型/平台：https://github.com/koolshare/rogsoft#rogsoft"
			echo_date "退出安装！"
			rm -rf /tmp/openlist* >/dev/null 2>&1
			exit 1
			;;
		2)
			echo_date "Alist插件目前仅支持hnd机型中的armv8机型！"
			echo_date "你的路由器不能安装！！!"
			echo_date "退出安装！"
			rm -rf /tmp/openlist* >/dev/null 2>&1
			exit 1
			;;
		0|*)
			rm -rf /tmp/openlist* >/dev/null 2>&1
			exit 0
			;;
	esac
}

dbus_nset(){
	# set key when value not exist
	local ret=$(dbus get $1)
	if [ -z "${ret}" ];then
		dbus set $1=$2
	fi
}


install_now() {
	# default value
	local TITLE="OpenList 文件列表"
	local DESCR="一个支持多种存储的文件列表程序，使用 Gin 和 Solidjs。"
	local PLVER=$(cat ${DIR}/version)

	# stop signdog first
	enable=$(dbus get openlist_enable)
	if [ "${enable}" == "1" -a "$(pidof openlist)" ];then
		echo_date "先关闭openlist插件！以保证更新成功！"
		sh /koolshare/scripts/openlist_config.sh stop
	fi
	
	# remove some files first
	find /koolshare/init.d/ -name "*openlist*" | xargs rm -rf
	rm -rf /koolshare/openlist/openlist.version >/dev/null 2>&1

	# isntall file
	echo_date "安装插件相关文件..."
	cp -rf /tmp/${module}/bin/* /koolshare/bin/
	cp -rf /tmp/${module}/res/* /koolshare/res/
	cp -rf /tmp/${module}/scripts/* /koolshare/scripts/
	cp -rf /tmp/${module}/webs/* /koolshare/webs/
	cp -rf /tmp/${module}/uninstall.sh /koolshare/scripts/uninstall_${module}.sh
	mkdir -p /koolshare/openlist/
	
	#创建开机自启任务
	[ ! -L "/koolshare/init.d/S99openlist.sh" ] && ln -sf /koolshare/scripts/openlist_config.sh /koolshare/init.d/S99openlist.sh
	[ ! -L "/koolshare/init.d/N99openlist.sh" ] && ln -sf /koolshare/scripts/openlist_config.sh /koolshare/init.d/N99openlist.sh

	# Permissions
	chmod +x /koolshare/scripts/* >/dev/null 2>&1
	chmod +x /koolshare/bin/openlist >/dev/null 2>&1

	# dbus value
	echo_date "设置插件默认参数..."
	dbus set ${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_version="${PLVER}"
	dbus set softcenter_module_${module}_install="1"
	dbus set softcenter_module_${module}_name="${module}"
	dbus set softcenter_module_${module}_title="${TITLE}"
	dbus set softcenter_module_${module}_description="${DESCR}"

	# 检查插件默认dbus值
	dbus_nset openlist_port "5244"
	dbus_nset openlist_token_expires_in "48"
	dbus_nset openlist_cert_file "/etc/cert.pem"
	dbus_nset openlist_key_file "/etc/key.pem"

	# reenable
	if [ "${enable}" == "1" ];then
		echo_date "重新启动openlist插件！"
		sh /koolshare/scripts/openlist_config.sh boot_up
	fi

	# finish
	echo_date "${TITLE}插件安装完毕！"
	exit_install
}

checkIsNeedMigrate() {
	local isMigrate=$(dbus get openlist_is_migrate)
	if [ "${isMigrate}" != "1" ]; then
		echo_date "--------------------------------"
		local alistDir="/koolshare/alist"
		local openlistDir="/koolshare/configs/openlist"
		# 检查alist目录是否存在
		if [ -d "${alistDir}" ]; then
			if [ ! -d "${openlistDir}" ]; then
				mkdir -p ${openlistDir}
				cp -rf ${alistDir}/* ${openlistDir}/
				echo_date "检测到 Alist 配置文件，开始迁移..."
			else
				echo_date "检测到 OpenList 配置文件已存在，跳过此步骤。"
			fi
		else
			echo_date "没有检测到旧版本的 Alist 配置文件，跳过此步骤。"
			return
		fi
		# 迁移 dbus 配置
		migrateDbus
		# 停止 Alist 进程
		local alistPid=$(pidof alist)
		if [ -n "${alistPid}" ]; then
			if [ -f "/koolshare/scripts/alist_config.sh" ] ; then
				/koolshare/scripts/alist_config.sh stop >/dev/null 2>&1
				dbus set alist_enable="0"
				echo_date "尝试停止 Alist 进程..."
			else
				echo_date "未找到 Alist 配置脚本，跳过..."
			fi
		else
			echo_date "没有检测到 Alist 进程，跳过此步骤"
		fi
		# 修改某些字段值
		migrateSqliteData
		echo_date "Alist 迁移完成，已将配置文件迁移到 OpenList 目录。"
		echo_date "--------------------------------"
	fi
	# 设置迁移标志
	dbus set openlist_is_migrate="1"
}

migrateDbus(){
	local txt=$(dbus list alist)
	printf "%s\n" "$txt" |
	while IFS= read -r line; do
		# 替换 alist_ 为 openlist_
		new_line=$(echo "$line" | sed 's/alist_/openlist_/')
		dbus set "$new_line"
		dbus remove openlist_binver
	done
}

migrateSqliteData() {
    # 1. 检查配置文件是否存在
    local config_file="/koolshare/configs/openlist/config.json"
    if [ ! -f "$config_file" ]; then
        echo_date "没有检测到 OpenList 配置文件，跳过数据库迁移。"
        return 1
    fi

    # 2. 提取表前缀
    local tablePrefix=$(cat /koolshare/configs/openlist/config.json |  grep -o '"table_prefix": "[^"]*"' | cut -d'"' -f4)

    # 3. 检查数据库文件
    local openlistDb="/koolshare/configs/openlist/data.db"
    if [ ! -f "$openlistDb" ]; then
        echo_date "没有检测到 OpenList 数据库，跳过数据库迁移。"
        return 1
    fi

    # 4. 创建临时备份
    local backupDb="${openlistDb}.bak"
    if ! cp "$openlistDb" "$backupDb"; then
        echo_date "错误：无法创建数据库备份，跳过数据库迁移。"
        return 1
    fi
    # 5. 创建SQL语句
    local tmp_sql="/tmp/upload/openlist_migrate_temp.sql"
    cat > "$tmp_sql" <<EOF
BEGIN TRANSACTION;
UPDATE ${tablePrefix}setting_items SET value='OpenList' WHERE key='site_title';
UPDATE ${tablePrefix}setting_items SET value='https://cdn.oplist.org/gh/OpenListTeam/Logo@main/logo.svg' WHERE key='logo';
UPDATE ${tablePrefix}setting_items SET value='https://cdn.oplist.org/gh/OpenListTeam/Logo@main/logo.svg' WHERE key='favicon';
UPDATE ${tablePrefix}setting_items SET value='https://cdn.oplist.org/gh/OpenListTeam/Logo@main/logo.svg' WHERE key='audio_cover';
COMMIT;
EOF

    # 6. 执行SQL
    if sqlite3 "$openlistDb" < "$tmp_sql" 2>/dev/null; then
        echo_date "数据库已成功迁移到OpenList格式。"
    else
        echo_date "SQL执行失败，已恢复数据库。"
        mv "$backupDb" "$openlistDb"
        rm -f "$tmp_sql"
        return 1
    fi

    # 7. 清理
    rm -f "$tmp_sql"
    rm -f "$backupDb"
}

install() {
  get_model
  get_fw_type
  platform_test
  checkIsNeedMigrate
  install_now
}

install
