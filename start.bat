@echo off
chcp 65001 >nul
echo ============================================
echo   Arena Clash 本地启动脚本
echo ============================================
echo.

:: 检查 Python
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到 Python，请先安装 Python 3.11+
    pause
    exit /b 1
)

:: 检查 Node.js
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [错误] 未找到 Node.js，请先安装 Node.js 18+
    pause
    exit /b 1
)

:: 检查 .env 文件
if not exist ".env" (
    echo [提示] 未找到 .env 文件，从 .env.example 复制...
    copy .env.example .env
    echo [重要] 请编辑 .env 文件，修改数据库密码和 SECRET_KEY
    echo.
)

:: 安装后端依赖
echo [1/4] 安装后端 Python 依赖...
cd backend
if not exist ".venv" (
    python -m venv .venv
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q

:: 安装前端依赖
echo [2/4] 安装前端 Node.js 依赖...
cd ..\frontend
if not exist "node_modules" (
    npm install
) else (
    echo 已存在 node_modules，跳过安装
)

:: 启动后端
echo [3/4] 启动后端服务 (http://localhost:8000)...
cd ..\backend
start "Arena Clash Backend" cmd /k ".venv\Scripts\activate.bat && python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

:: 启动前端
echo [4/4] 启动前端服务 (http://localhost:3000)...
cd ..\frontend
start "Arena Clash Frontend" cmd /k "npm run dev"

cd ..
echo.
echo ============================================
echo   启动完成！
echo   前端: http://localhost:3000
echo   后端: http://localhost:8000
echo   API文档: http://localhost:8000/docs
echo ============================================
echo.
echo 首次运行请确保：
echo   1. PostgreSQL 已安装并运行，且已执行 sql/ 下的初始化脚本
echo   2. Redis 已安装并运行
echo   3. .env 文件中的数据库连接信息正确
echo.
pause
