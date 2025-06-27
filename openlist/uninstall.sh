#!/bin/sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

echo_date "正在删除插件资源文件..."
sh /koolshare/scripts/openlist_config.sh stop
rm -rf /koolshare/scripts/openlist_config.sh
rm -rf /koolshare/webs/Module_openlist.asp
rm -rf /koolshare/res/*openlist*
find /koolshare/init.d/ -name "*openlist*" | xargs rm -rf
rm -rf /koolshare/bin/openlist >/dev/null 2>&1
sed -i '/openlist_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
echo_date "插件资源文件删除成功..."
echo_date "--------------------------------"
#rm -rf /koolshare/configs/openlist # 删除配置文件及数据库文件
echo_date "数据无价！为防止误删，插件配置文件及数据库未删除。"
echo_date "如需彻底删除请执行下面命令："
echo_date ""
echo_date "rm -rf /koolshare/configs/openlist"
echo_date ""
echo_date "--------------------------------"

rm -rf /koolshare/scripts/uninstall_openlist.sh
echo_date "已成功移除插件... Bye~Bye~"
echo_date ""