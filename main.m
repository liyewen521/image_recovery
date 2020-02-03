% Tips：尽量用double型变量来进行运算。因为uint8型变量当相减的结果小于 0 就会出错，
% 虽然int8不会，但是还是挺麻烦的。uint8在进行取整取余操作时候容易出意想不到的问题
% 2019.4.4 
% 1. 修改了滑动方程的BUG
% 2. 恢复信息通过自适应方法得到

clc;        % 清除命令行窗口
clear;      % 清除变量
close all;  % 清除绘图

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%图像水印嵌入%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 载入图片
relative_path = ['.', filesep(), 'data', filesep()]; 
load([relative_path, 'School_Motto.mat']);
image256x256 = School_Motto;
[image_height, image_width] = size(image256x256);
% 图像块划分
block_height = 2;
block_width = 2;
table_height = image_height / block_height;
table_width = image_width / block_width;


% 生成双伪随机链，由于生成时间长，可以将数据生成后保存
% [logistic_sequence_output] = get_logistic_sequence(0.3, 3.991, table_height, table_width);
% logistic_sequence_one = [logistic_sequence_output + 1; 1 : table_height * table_width];
% save('logistic_sequence_one.mat', 'logistic_sequence_one');
% 
% [logistic_sequence_output] = get_logistic_sequence(0.5, 3.895, table_height, table_width);
% logistic_sequence_two = [logistic_sequence_output + 1; 1 : table_height * table_width];
% save('logistic_sequence_two.mat', 'logistic_sequence_two');

% 导入保存好的双伪随机链数据
load([relative_path, 'logistic_sequence_one.mat']);
load([relative_path, 'logistic_sequence_two.mat']);


% 显示输入图像
image_data = image256x256(1 : table_height * block_height, 1 : table_width * block_width);
figure('NumberTitle', 'off', 'Name', 'Image Data'); % 确定图片的输出格式 
imshow(image_data);                          % 图片显示
% title('Image Data');

% 求各个块最佳的像素值
[pre_embed_recover_data] = find_best_method_adaptive(image_data, table_height, table_width, block_height, block_width);
pre_embed_recover_data_vector = [reshape(pre_embed_recover_data', 1, table_height * table_width); 1 : table_height * table_width];

% 显示恢复信息的PSNR
pre_embed_recover_data_256 = zeros(table_height * block_height, table_width * block_width, 'uint8');
for i = 1 : table_height
    for j = 1 : table_width
        pre_embed_recover_data_256(i * block_height    , j * block_width) = pre_embed_recover_data(i, j);
        pre_embed_recover_data_256(i * block_height - 1, j * block_width) = pre_embed_recover_data(i, j);
        pre_embed_recover_data_256(i * block_height    , j * block_width - 1) = pre_embed_recover_data(i, j);
        pre_embed_recover_data_256(i * block_height - 1, j * block_width - 1) = pre_embed_recover_data(i, j);
    end
end

[peak_snr, snr] = psnr(image_data, pre_embed_recover_data_256, 255);
fprintf('\nThe Watermark Peak-SNR value is %0.4f', peak_snr);
fprintf('\nThe SNR value is %0.4f \n', snr);

% 生成待嵌入的12bit恢复信息，logistic_sequence_one嵌入在高5位，
% logistic_sequence_two嵌入在中5位，再生成 p，v
% 原像素位置 .....
% 被隐藏位置 .....
watermark_map_vector = zeros(1, table_height * table_width, 'uint16');
number_of_pixel_bit = 8;

for i = 1 : table_height * table_width
    for k = number_of_pixel_bit : - 1 : number_of_pixel_bit - 4
        watermark_map_vector(i) = bitset( watermark_map_vector(i), k+4, bitget( pre_embed_recover_data_vector(1, logistic_sequence_one(1, i) ), k) );
        watermark_map_vector(i) = bitset( watermark_map_vector(i), k-1, bitget( pre_embed_recover_data_vector(1, logistic_sequence_two(1, i) ), k) );       
    end
    bit_a7 = bitget(watermark_map_vector(i), 12);
    bit_a6 = bitget(watermark_map_vector(i), 11);
    bit_a5 = bitget(watermark_map_vector(i), 10);   
    bit_a4 = bitget(watermark_map_vector(i), 9);
    bit_a3 = bitget(watermark_map_vector(i), 8);
    bit_b7 = bitget(watermark_map_vector(i), 7);
    bit_b6 = bitget(watermark_map_vector(i), 6);
    bit_b5 = bitget(watermark_map_vector(i), 5);
    bit_b4 = bitget(watermark_map_vector(i), 4);
    bit_b3 = bitget(watermark_map_vector(i), 3);
    bit_p = xor(xor(xor(xor(xor(xor(xor(xor(xor(bit_a7, bit_a6), bit_a5), bit_a4), bit_a3), bit_b7), bit_b6), bit_b5), bit_b4), bit_b3);
%     block_index_xor = xor(bitget(i,8),xor(bitget(i,7),xor(bitget(i,6),xor(bitget(i,5),xor(bitget(i,4),xor(bitget(i,3),xor(bitget(i,2),bitget(i,1))))))));
    bit_v = uint8( ~ bit_p);
    watermark_map_vector(i) = bitset(watermark_map_vector(i), 2, bit_p);
    watermark_map_vector(i) = bitset(watermark_map_vector(i), 1, bit_v);   
end

% 将 watermark_map_matrix 嵌入到原图像中，并使用平滑函数
watermark_map_matrix = reshape(watermark_map_vector, table_height, table_width)';
image_data_embed = zeros(table_height * block_height, table_width * block_width, 'uint8');
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        image_data_embed(1 + block_height * (i-1)    , 1 + block_width * (j - 1)    ) = smooth_function(image_data(1 + block_height * (i - 1)    , 1 + block_width * (j - 1)    ), bitget(watermark_map_matrix(i, j), 12), bitget(watermark_map_matrix(i, j), 11), bitget(watermark_map_matrix(i, j), 10));
        image_data_embed(1 + block_height * (i-1)    , 1 + block_width * (j - 1) + 1) = smooth_function(image_data(1 + block_height * (i - 1)    , 1 + block_width * (j - 1) + 1), bitget(watermark_map_matrix(i, j),  9), bitget(watermark_map_matrix(i, j),  8), bitget(watermark_map_matrix(i, j),  7));
        image_data_embed(1 + block_height * (i-1) + 1, 1 + block_width * (j-1)      ) = smooth_function(image_data(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1)    ), bitget(watermark_map_matrix(i, j),  6), bitget(watermark_map_matrix(i, j),  5), bitget(watermark_map_matrix(i, j),  4));
        image_data_embed(1+block_height*(i-1)+1,1+block_width*(j-1)+1) = smooth_function(image_data(1+block_height*(i-1)+1,1+block_width*(j-1)+1),bitget(watermark_map_matrix(i,j),3),bitget(watermark_map_matrix(i,j),2),bitget(watermark_map_matrix(i,j),1));       
    end
end

% 输出嵌入图片的PSNR
[peak_snr, snr] = psnr(image_data, image_data_embed, 255);
fprintf('\nThe Embeded Image Peak-SNR value is %0.4f', peak_snr);
fprintf('\nThe SNR value is %0.4f \n', snr);

%对水印插入的图像进行显示
figure('NumberTitle', 'off', 'Name', 'Image Data Embeded'); % 确定图片的输出格式 
imshow(image_data_embed);                          % 图片显示
% title('Image Data Embeded');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%图像篡改%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
image_data_tampered = image_data_embed;
% not_tamper_distance=16;
% for i=1:16
%    image_data_tampered(3+(i-1)*not_tamper_distance:3+(i-1)*not_tamper_distance+7,1:256)=0;
%    % 指定损坏区域 50% ,16个横杠
% end
% for i=1:16
%    image_data_tampered(1:256,3+(i-1)*not_tamper_distance:3+(i-1)*not_tamper_distance+7)=0;
%     % 指定损坏区域 50% ,16个竖杠
% end

% not_tamper_distance=14;
% for i = 1 : 18
%     for j = 1 : 18
%         image_data_tampered(5+(i-1)*not_tamper_distance:5+(i-1)*not_tamper_distance+9,5+(j-1)*not_tamper_distance:5+(j-1)*not_tamper_distance+9)=0;    
%     end
% end
% image_data_tampered(1:128, 1:256)= 0;       % 指定损坏区域 50%，上
% image_data_tampered(1:256, 1:128)= 0;       % 指定损坏区域 50% ,左
% image_data_tampered(1:128, 1:128)= 0; 
% image_data_tampered(129:256, 129:256)= 0;   % 指定损坏区域 50% ,反斜杠
% for i= 256 : -1 : 1
%     image_data_tampered(257-i, 1:i)= 0;     % 指定损坏区域 50% ,斜杠
% end
% for i= 1 : 1 : 256
%     image_data_tampered(257-i, i:256)= 0;   % 指定损坏区域 50% ,斜杠
% end
% image_data_tampered(1:256  , 1:64)= 0;      % 指定损坏区域 25% 左
% image_data_tampered(1:84   , 1:256)= 0;     % 指定损坏区域 34% 上
% image_data_tampered(1:6    , 1:256)= 0;     % 指定损坏区域 2.4%
% image_data_tampered(109:148, 109:148)= 0;   % 指定损坏区域 2.4%
% image_data_tampered(89:168 , 89:168)= 0;    % 指定损坏区域 9.7%
% image_data_tampered(80:178 , 80:178)= 0;    % 指定损坏区域 15.25%
% image_data_tampered(71:184 , 71:184)= 0;    % 指定损坏区域 19.83%
% image_data_tampered(65:192 , 65:192)= 0;    % 指定损坏区域 25%
% image_data_tampered(59:198 , 59:198)= 0;    % 指定损坏区域 29.90%
% image_data_tampered(54:204 , 54:204)= 0;    % 指定损坏区域 35.25%
% image_data_tampered(47:210 , 47:210)= 0;    % 指定损坏区域 40%
% image_data_tampered(43:214 , 43:214)= 0;    % 指定损坏区域 45.14%
% image_data_tampered(39:219 , 39:219)= 0;    % 指定损坏区域 50.43%
% image_data_tampered(33:222 , 33:222)= 0;    % 指定损坏区域 55.0842%
% image_data_tampered(29:228 , 29:228)= 0;    % 指定损坏区域 61%
% image_data_tampered(25:230 , 25:230)= 0;    % 指定损坏区域 65%
% image_data_tampered(21:234 , 21:234)= 0;    % 指定损坏区域 70%
% image_data_tampered(17:238 , 17:238)= 0;    % 指定损坏区域 75%
% image_data_tampered(13:242 , 13:242)= 0;    % 指定损坏区域 80%
% image_data_tampered(11:246 , 11:246)= 0;    % 指定损坏区域 85%
% image_data_tampered(7:250  , 7:250)= 0;     % 指定损坏区域 90%
% image_data_tampered(3:252  , 3:252)= 0;     % 指定损坏区域 95%
% image_data_tampered(47:210 , 41:124) = 0;   % 指定损坏区域 21% 左边
% image_data_tampered(47:210 , 133:216) = 0;  % 指定损坏区域 21% 右边
image_data_tampered(15:240   , 80:200) = 0;  % 校徽篡改
% load([relative_path, 'lena_collage_attack.mat']);
% image_data_tampered(47:210, 133:216) = image_data_tampered(47:210, 41:124); %拼贴攻击，21%
% lena_collage_attack = image_data_tampered(47:210,41:124);
% save('lena_collage_attack.mat','lena_collage_attack');
image_data_recovered = image_data_tampered;
figure('NumberTitle', 'off', 'Name', 'Image Data Tampered');	% 确定图片的输出格式 
imshow(image_data_tampered);                                  	% 图片显示
% title('Image Data Tampered');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%图像恢复%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% 篡改块一级检测
block_valid_or_invalid = ones(table_height, table_width, 'logical');
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        bit_a7 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1)), 3));
        bit_a6 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1)), 2));
        bit_a5 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1)), 1));   
        
        bit_a4 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1) + 1), 3));
        bit_a3 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1) + 1), 2));
        bit_b7 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1), 1 + block_width *(j - 1) + 1), 1));
        
        bit_b6 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1)), 3));
        bit_b5 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1)), 2));
        bit_b4 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1)), 1));
        
        bit_b3 = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1) + 1), 3));
        bit_p  = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1) + 1), 2));
        bit_v  = uint16(bitget(image_data_tampered(1 + block_height * (i - 1) + 1, 1 + block_width * (j - 1) + 1), 1)); 
        
        bit_p_calculate = xor(xor(xor(xor(xor(xor(xor(xor(xor(bit_a7, bit_a6), bit_a5), bit_a4), bit_a3), bit_b7), bit_b6), bit_b5), bit_b4), bit_b3);
        block_index = (i - 1) * table_width + j;
%         block_index_xor_calculate = xor(bitget(block_index, 8),xor(bitget(block_index, 7),xor(bitget(block_index, 6),xor(bitget(block_index, 5),xor(bitget(block_index, 4),xor(bitget(block_index, 3),xor(bitget(block_index, 2),bitget(block_index, 1))))))));
        if (bit_p_calculate == bit_p) && (bit_v == uint8( ~ bit_p_calculate))
            block_valid_or_invalid(i, j) = 1;
        else
            block_valid_or_invalid(i, j) = 0; 
        end
    end
end

% 篡改块二级检测
block_valid_or_invalid_backup = block_valid_or_invalid;
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid(i, j) == 1
            % 计算此处隐藏的恢复数据a的数值
            bit_7 = bitget(image_data_tampered(i * block_height -1, j * block_width - 1), 3);
            bit_6 = bitget(image_data_tampered(i * block_height -1, j * block_width - 1), 2);
            bit_5 = bitget(image_data_tampered(i * block_height -1, j * block_width - 1), 1);
            bit_4 = bitget(image_data_tampered(i * block_height -1, j * block_width)    , 3);
            bit_3 = bitget(image_data_tampered(i * block_height -1, j * block_width)    , 2);
            embed_value = 128 * bit_7 + 64 * bit_6 + 32 * bit_5 + 16 * bit_4 + 8 * bit_3;
            find_embed_index = (i - 1) * table_height + j;
            find_index = logistic_sequence_one(1, find(logistic_sequence_one(2, :) == find_embed_index));
            block_row = floor(find_index / table_width) + 1;
            block_col = mod(find_index, table_width);
            if block_col == 0
                block_row = block_row - 1;
                block_col = table_width;
            end
            if block_valid_or_invalid(block_row, block_col) == 1
                original_value = floor(double(pre_embed_recover_data(block_row, block_col)) / 8) * 8;
                if original_value ~= embed_value
                    block_valid_or_invalid_backup(i, j)=0;
                end
            end
            
            % 计算此处隐藏的恢复数据b的数值
            bit_7 = bitget(image_data_tampered(i * block_height - 1, j * block_width    ), 1);
            bit_6 = bitget(image_data_tampered(i * block_height    , j * block_width - 1), 3);
            bit_5 = bitget(image_data_tampered(i * block_height    , j * block_width - 1), 2);
            bit_4 = bitget(image_data_tampered(i * block_height    , j * block_width - 1), 1);
            bit_3 = bitget(image_data_tampered(i * block_height    , j * block_width    ), 3);
            embed_value = 128 * bit_7 + 64 * bit_6 + 32 * bit_5 + 16 * bit_4 + 8 * bit_3;
            find_embed_index = (i - 1) * table_height + j;
            find_index = logistic_sequence_two(1, find(logistic_sequence_two(2, :) == find_embed_index));
            block_row = floor(find_index / table_width) + 1;
            block_col = mod(find_index, table_width);
            if block_col == 0
                block_row = block_row - 1;
                block_col = table_width;
            end
            if block_valid_or_invalid(block_row, block_col) == 1
                original_value = floor(double(pre_embed_recover_data(block_row, block_col)) / 8) * 8;
                if original_value ~= embed_value
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            end
            % 结束
        end
    end
end
block_valid_or_invalid = block_valid_or_invalid_backup;

% 篡改块三级检测
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid(i, j) == 1
            if i == 1 && j == 1 
                %元组(E,SE,S)
                if (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i == 1 && j == table_width
                %元组(W,SW,S)
                if (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i == table_height && j == table_width
                %元组(W,NW,N)
                if (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i == table_height && j == 1
                %元组(N,NE,E)
                if (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i > 1 && i < table_height && j == 1
                %元组(N,NE,E)(E,SE,S)
                if  (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j + 1) == 0  && block_valid_or_invalid(i, j + 1) == 0) || (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i == 1 && j > 1 && j < table_width
                %元组(E,SE,S)(W,SW,S)
                if  (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0 )||(block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0)
                    block_valid_or_invalid_backup(i,j) = 0;
                end
            elseif i > 1 && i < table_height && j == table_width
                %元组(W,NW,N)(W,SW,S)
                if (block_valid_or_invalid(i - 1, j)==0 && block_valid_or_invalid(i - 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0) || (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            elseif i == table_height && j > 1 && j < table_width
                %元组(W,NW,N)(N,NE,E)
                if (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0) || (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            else
                %元组(W,NW,N)(N,NE,E)(E,SE,S)(W,SW,S)
                if (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0) || (block_valid_or_invalid(i - 1, j) == 0 && block_valid_or_invalid(i - 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0) || (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j + 1) == 0 && block_valid_or_invalid(i, j + 1) == 0 ) || (block_valid_or_invalid(i + 1, j) == 0 && block_valid_or_invalid(i + 1, j - 1) == 0 && block_valid_or_invalid(i, j - 1) == 0)
                    block_valid_or_invalid_backup(i, j) = 0;
                end
            end   
        end
    end
end
block_valid_or_invalid = block_valid_or_invalid_backup;

% 篡改块四级检测
block_invalid_count = 0;
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid(i,j) == 1
            if i == 1 && j == 1                             %1
                block_invalid_count = 0;
            elseif i == 1 && j == table_width               %2
                block_invalid_count = 0;
            elseif i == table_height && j == table_width    %3
                block_invalid_count = 0;
            elseif i == table_height && j == 1              %4
                block_invalid_count = 0;
            elseif i > 1 && i < table_height && j == 1      %5
                if block_valid_or_invalid(i - 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
            elseif i == 1 && j > 1 && j < table_width       %6
                if block_valid_or_invalid(i, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
            elseif i > 1 && i < table_height && j == table_width  %7
                if block_valid_or_invalid(i - 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i, j-1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
            elseif i == table_height && j > 1 && j < table_width  %8
                if block_valid_or_invalid(i, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
            else                                                   %9
                if block_valid_or_invalid(i, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i - 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j + 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j) == 0
                    block_invalid_count = block_invalid_count + 1;
                end
                if block_valid_or_invalid(i + 1, j - 1) == 0
                    block_invalid_count = block_invalid_count + 1;
                end              
            end            
            if block_invalid_count >= 5
                block_valid_or_invalid_backup(i, j) = 0;
                block_invalid_count = 0;
            else
                block_invalid_count = 0;
            end          
        end
    end
end
block_valid_or_invalid = block_valid_or_invalid_backup;

%以像素为单位得到篡改检测矩阵
image_valid_or_invalid = zeros(table_height * block_height,table_width * block_width);
for i = 1 : table_height    
    for j = 1 : table_width
        if block_valid_or_invalid(i, j) == 0
            for i_to_configure = ((i - 1) * block_height + 1) : 1 : i * block_height  
                for j_to_configure = ((j - 1) * block_width + 1) : 1 : j * block_width
                    image_valid_or_invalid(i_to_configure, j_to_configure) = 0;
                end
            end
        elseif block_valid_or_invalid(i, j) == 1
            for i_to_configure = ((i - 1) * block_height + 1) : 1 : i * block_height  
                for j_to_configure = ((j - 1) * block_width + 1): 1 : j * block_width
                    image_valid_or_invalid(i_to_configure, j_to_configure) = 1;
                end
            end
        end
    end
end

% 输出篡改比例
invaild_count = 0;
for i = 1 : table_height * block_height    
    for j = 1 : table_width * block_width
        if (image_valid_or_invalid(i, j)~=1)
            invaild_count = invaild_count + 1;
        end
    end
end
tampered_percentage = invaild_count * 100 / (table_height * block_height * table_width * block_width);
fprintf('The percentage of tampered is %0.4f%%\n', tampered_percentage);
% 显示标准篡改图
image_valid_or_invalid_standard = zeros(table_height * block_height, table_width * block_width, 'uint8');
for i = 1 : table_height * block_height    
    for j = 1 : table_width * block_width
        if (image_valid_or_invalid(i, j)==1)
            image_valid_or_invalid_standard(i, j) = 0;
        else
            image_valid_or_invalid_standard(i, j) = 255;
        end
    end
end
figure('NumberTitle', 'off', 'Name', 'Image Data Standard'); % 确定图片的输出格式 
imshow(image_valid_or_invalid_standard);                          % 图片显示
% title('Image Data Recovered');
% 整体提取恢复信息，用于接下来的一级修复
watermark_recover = zeros(1, table_height * table_width, 'uint16');
for i = 1 : table_height * table_width
    bit_7_3_get = 0;
    find_index = find(logistic_sequence_one(1, :)==i);   
    block_row = floor(find_index / table_width) + 1;
    block_col = mod(find_index, table_width);
    if block_col == 0
       block_row = block_row - 1;
       block_col = table_width;
    end
    if block_valid_or_invalid(block_row, block_col) == 1
        bit_7_3_get = 1;
        bit_7 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width - 1), 3);
        bit_6 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width - 1), 2);
        bit_5 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width - 1), 1);
        bit_4 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width), 3);
        bit_3 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width), 2);
    end
    
    find_index = find(logistic_sequence_two(1, :) == i);   
    block_row = floor(find_index / table_width) + 1;
    block_col = mod(find_index, table_width);
    if block_col == 0
       block_row = block_row - 1;
       block_col = table_width;
    end
    if (block_valid_or_invalid(block_row, block_col) == 1) && (bit_7_3_get == 0)
        bit_7_3_get = 1;
        bit_7 = bitget(image_data_tampered(block_row * block_height - 1, block_col * block_width    ), 1);
        bit_6 = bitget(image_data_tampered(block_row * block_height    , block_col * block_width - 1), 3);
        bit_5 = bitget(image_data_tampered(block_row * block_height    , block_col * block_width - 1), 2);
        bit_4 = bitget(image_data_tampered(block_row * block_height    , block_col * block_width - 1), 1);
        bit_3 = bitget(image_data_tampered(block_row * block_height    , block_col * block_width    ), 3);
    end
    if bit_7_3_get == 1
        watermark_recover(i) = 128 * bit_7 + 64 * bit_6 + 32 * bit_5 + 16 * bit_4 + 8 * bit_3;
        bit_7 = 0; bit_6 = 0; bit_5 = 0; bit_4 = 0; bit_3 = 0;
    else
        watermark_recover(i) = 9999;
        bit_7 = 0; bit_6 = 0; bit_5 = 0; bit_4 = 0; bit_3 = 0;        
    end
end
watermark_recover_matrix = reshape(watermark_recover, table_height, table_width)';

% 一级恢复
% 备份篡改检测矩阵，当一级恢复完成，将备份矩阵置1，最后在统一赋值给原矩阵
block_valid_or_invalid_backup = block_valid_or_invalid;
for i = 1 : table_height    
    for j = 1 : table_width
        if block_valid_or_invalid(i, j) == 0 && watermark_recover_matrix(i, j) ~= 9999
            image_data_recovered(1 + block_height * (i - 1)  , 1 + block_width * (j - 1)  ) = watermark_recover_matrix(i,j);
            image_data_recovered(1 + block_height * (i - 1)  , 1 + block_width * (j - 1)+1) = watermark_recover_matrix(i,j);
            image_data_recovered(1 + block_height * (i - 1)+1, 1 + block_width * (j - 1)  ) = watermark_recover_matrix(i,j);
            image_data_recovered(1 + block_height * (i - 1)+1, 1 + block_width * (j - 1)+1) = watermark_recover_matrix(i,j);
            block_valid_or_invalid_backup(i, j)=1;
        end
    end
end

% 统计一级恢复尚未恢复的比率
block_equal_zero = 0;
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid_backup(i, j) == 0
            block_equal_zero = block_equal_zero + 1;
        end
    end
end
fprintf('The percentage of blocks not recovered after stage-1 tamper recovery is %0.4f%%\n', (block_equal_zero * 100) / (table_width * table_height));

% 二级恢复，对恢复块和未篡改块采用不同权重
rate = 1.5;
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid_backup(i, j) == 0   %表示当前块被篡改，且一级修复没有还原
            pixel_original_count = double(1);
            pixel_recovered_count = double(1);
            n_original = zeros(1,12); 
            n_recovered = zeros(1,12);           
            if (i > 1) && (i < table_height) && (j > 1) && (j < table_width)% 1
                % N1
                if block_valid_or_invalid_backup(i - 1, j - 1) == 1
                    if block_valid_or_invalid(i - 1, j - 1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1 + block_height * (i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N3
                if block_valid_or_invalid_backup(i-1,j+1) == 1
                   if block_valid_or_invalid(i-1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end                
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N5
                if block_valid_or_invalid_backup(i+1,j+1) == 1
                   if block_valid_or_invalid(i+1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N7
                if block_valid_or_invalid_backup(i+1,j-1) == 1
                    if block_valid_or_invalid(i+1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end    

            elseif (i > 1) && (i < table_height) && (j==1)% 2
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N3
                if block_valid_or_invalid_backup(i-1,j+1) == 1
                   if block_valid_or_invalid(i-1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end                
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N5
                if block_valid_or_invalid_backup(i+1,j+1) == 1
                   if block_valid_or_invalid(i+1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end          

            elseif (i > 1) && (i < table_height) && (j==table_width)% 3
                % N1
                if block_valid_or_invalid_backup(i-1,j-1) == 1
                    if block_valid_or_invalid(i-1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N7
                if block_valid_or_invalid_backup(i+1,j-1) == 1
                    if block_valid_or_invalid(i+1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end          
            elseif (i==1)&& (j > 1) && (j < table_width)% 4              
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N5
                if block_valid_or_invalid_backup(i+1,j+1) == 1
                   if block_valid_or_invalid(i+1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N7
                if block_valid_or_invalid_backup(i+1,j-1) == 1
                    if block_valid_or_invalid(i+1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end          
            elseif (i==table_height) && (j > 1) && (j < table_width)% 5
                % N1
                if block_valid_or_invalid_backup(i-1,j-1) == 1
                    if block_valid_or_invalid(i-1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N3
                if block_valid_or_invalid_backup(i-1,j+1) == 1
                   if block_valid_or_invalid(i-1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end                
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end          
            elseif (i==1)&&(j==1)% 6             
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N5
                if block_valid_or_invalid_backup(i+1,j+1) == 1
                   if block_valid_or_invalid(i+1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end         
            elseif (i==1)&&(j==table_width)% 7
                % N6
                if block_valid_or_invalid_backup(i+1,j) == 1
                    if block_valid_or_invalid(i+1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N7
                if block_valid_or_invalid_backup(i+1,j-1) == 1
                    if block_valid_or_invalid(i+1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i+1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1+1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end          
            elseif (i==table_height)&&(j==1)% 8
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N3
                if block_valid_or_invalid_backup(i-1,j+1) == 1
                   if block_valid_or_invalid(i-1,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end                
                % N4
                if block_valid_or_invalid_backup(i,j+1) == 1
                    if block_valid_or_invalid(i,j+1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j+1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1+1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end      
            elseif (i==table_height)&&(j==table_width)% 9
                % N1
                if block_valid_or_invalid_backup(i-1,j-1) == 1
                    if block_valid_or_invalid(i-1,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N2
                if block_valid_or_invalid_backup(i-1,j) == 1
                    if block_valid_or_invalid(i-1,j) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i-1,j) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1-1)+1,1+block_width*(j-1)));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end
                % N8
                if block_valid_or_invalid_backup(i,j-1) == 1
                    if block_valid_or_invalid(i,j-1) == 1 %表示这是未篡改的块
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                        n_original(pixel_original_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_original_count = pixel_original_count + 1;
                    elseif block_valid_or_invalid(i,j-1) == 0 %表示这是恢复的块
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1),1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                        n_recovered(pixel_recovered_count) = uint16(image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1-1)+1));
                        pixel_recovered_count = pixel_recovered_count + 1;
                    end
                end                                                     
            end
            % 计算自适应占比
            probability_original = rate/((pixel_original_count-1)*rate+(pixel_recovered_count-1));
            probability_recovered = 1.0/((pixel_original_count-1)*rate+(pixel_recovered_count-1));

            %预测当前块的像素值
            n_forecast = sum(probability_original*n_original) +  sum(probability_recovered*n_recovered);

            %将预测像素值填入当前块，并将备份块置1
            image_data_recovered(1+block_height*(i-1),1+block_width*(j-1)) = n_forecast;
            image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1)) = n_forecast;
            image_data_recovered(1+block_height*(i-1),1+block_width*(j-1)+1) = n_forecast;
            image_data_recovered(1+block_height*(i-1)+1,1+block_width*(j-1)+1) = n_forecast;
            block_valid_or_invalid_backup(i,j) = 1;
        end
        % 结束       
    end
end

% 二级恢复尚未恢复的比率
block_equal_zero = 0;
for i = 1 : 1 : table_height
    for j = 1 : 1 : table_width
        if block_valid_or_invalid_backup(i, j) == 0
            block_equal_zero = block_equal_zero + 1;
        end
    end
end
fprintf('The percentage of blocks not recovered after stage-2 tamper recovery is %0.4f%%\n', (block_equal_zero * 100) / (table_width * table_height));

% 显示恢复图像的PSNR
% error_value = double(image_data(109:148,109:148)) - double(image_data_recovered(109:148,109:148));
[peak_snr,snr] = psnr(image_data,image_data_recovered, 255);
fprintf('\nThe Recovered Image Peak-SNR value is %0.4f', peak_snr);
fprintf('\nThe SNR value is %0.4f \n', snr);
% 显示恢复完成的图像
figure('NumberTitle', 'off', 'Name', 'Image Data Recovered'); % 确定图片的输出格式 
imshow(image_data_recovered);                          % 图片显示
% title('Image Data Recovered');