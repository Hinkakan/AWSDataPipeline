set path_cwd=D:\Coding\AWSDataPipeline\
set lambda_func=%1
set dir_name=%lambda_func%_lambda_dist_pkg
set req=%path_cwd%%lambda_func%\requirements.txt
cd %path_cwd%
mkdir %dir_name%
pip install -r %req% --target %path_cwd%%dir_name% --platform manylinux2014_x86_64 --implementation cp --python 3.9 --only-binary=:all: --upgrade 
xcopy %path_cwd%%lambda_func% %path_cwd%%dir_name% /s /y