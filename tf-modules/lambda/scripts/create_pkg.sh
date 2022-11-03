export lambda_func=$1
export dir_name=${lambda_func}_lambda_dist_pkg
export req=${lambda_func}/requirements.txt
mkdir ${dir_name}
pip3 install -r $(pwd)/${req} --target $(pwd)/${dir_name} --platform manylinux2014_x86_64 --implementation cp --python 3.9 --only-binary=:all: --upgrade
cp -R $(pwd)/${lambda_func}/. $(pwd)/${dir_name}