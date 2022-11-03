export lambda_func=$1
export dir_name=${lambda_func}_lambda_dist_pkg
echo ${dir_name}
export req=${lambda_func}/requirements.txt
echo ${req}
mkdir ${dir_name}
ls
pip3 install -r $(pwd)/${req} --target $(pwd)/${dir_name} --upgrade
cp -R $(pwd)/${lambda_func}/. $(pwd)/${dir_name}