title="欢迎回来！"
message="登录脚本已经执行完成"

osascript -e "set volume output volume 0"
osascript -e "set volume output muted true"

osascript -e "display notification \"${message}\" with title \"${title}\""