set lambda_func=%1
set env=%2
set dir_name=%lambda_func%_%env%_lambda_dist_pkg
set req=%lambda_func%\requirements.txt
mkdir %dir_name%
pip install -r %req% --target %dir_name% --platform manylinux2014_x86_64 --implementation cp --python 3.9 --only-binary=:all: --upgrade 
xcopy %lambda_func% %dir_name% /s /y