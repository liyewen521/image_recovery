% ISAIR 2019论文，双伪随机链的置乱图
clc;        % 清除命令行窗口
clear;      % 清除变量
close all;  % 清除绘图

% 载入图片
image256x256= imread('Lena256x256.bmp');      % 读取Lena图片
[image_height,image_width] = size(image256x256);

% 图像块划分
block_height = 2;
block_width = 2;
table_height = image_height/block_height;
table_width = image_width/block_width;

% 生成 伪随机链
% [logistic_sequence_output]=get_logistic_sequence(0.3,3.991,image_height,image_width);
% logistic_sequence_dpcc = [logistic_sequence_output+1;1:image_height*image_width];
% save('logistic_sequence_dpcc.mat','logistic_sequence_dpcc');
load('logistic_sequence_dpcc.mat');

% 显示输入图像
image_data = image256x256(1 : table_height*block_height,1 : table_width*block_width);
figure('NumberTitle', 'off', 'Name', 'Image Data'); % 确定图片的输出格式 
imshow(image_data);                          % 图片显示
title('Image Data');

% 用伪随机循环链对原图像进行置乱
image_data_vector = reshape(image_data',1,image_height*image_width);
image_data_reconstruct_vector = zeros(1,image_height*image_width,'uint8');
for i = 1 : image_height*image_width
    image_data_reconstruct_vector(i) = image_data_vector(logistic_sequence_dpcc(1,i));
end
image_data_reconstruct = reshape(image_data_reconstruct_vector,image_height,image_width)';

% 显示置乱的图像
figure('NumberTitle', 'off', 'Name', 'Image Data Reconstruct'); % 确定图片的输出格式 
imshow(image_data_reconstruct);                          % 图片显示
title('Image Data Reconstruct');




