function [watermark_data,best_method_matrix,method_percentage] = find_best_method(image_data,table_height,table_width,block_height,block_width)

%   for example ,the sorted block data is [a1,a2,a3,a4]        
%   method_index 1 average
%                2 median a2
%                3 median a3
%                4 median (a2+a3)/2
    % calculate the average
    i_avg = 0;
    j_avg = 0;
    image_data_avg = zeros(table_height,table_width,'uint8');
    for i = 1 : block_height : table_height*block_height
        i_avg = i_avg +1 ;
        for j = 1 : block_width : table_width*block_width
            j_avg = j_avg + 1;
            image_data_avg(i_avg,j_avg) = uint8( mean([image_data(i,j),image_data(i,j+1),image_data(i+1,j),image_data(i+1,j+1)]) );
        end
        j_avg = 0;
    end
    % calculate the median£¬a2
    i_med = 0;
    j_med = 0;
    image_data_median_a2 = zeros(table_height,table_width,'uint8');
    for i = 1 : block_height : table_height*block_height
        i_med = i_med +1 ;
        for j = 1 : block_width : table_width*block_width
            j_med = j_med + 1;
            image_data_median_a2(i_med,j_med) = uint8( median([-1,image_data(i,j),image_data(i,j+1),image_data(i+1,j),image_data(i+1,j+1)]) );
        end
        j_med = 0;
    end
    % calculate the median£¬a3
    i_med = 0;
    j_med = 0;
    image_data_median_a3 = zeros(table_height,table_width,'uint8');
    for i = 1 : block_height : table_height*block_height
        i_med = i_med +1 ;
        for j = 1 : block_width : table_width*block_width
            j_med = j_med + 1;
            image_data_median_a3(i_med,j_med) = uint8( median([image_data(i,j),image_data(i,j+1),image_data(i+1,j),image_data(i+1,j+1),9999]) );
        end
        j_med = 0;
    end
    % calculate the median£¬(a2+a3)/2
    i_med = 0;
    j_med = 0;
    image_data_median = zeros(table_height,table_width,'uint8');
    for i = 1 : block_height : table_height*block_height
        i_med = i_med +1 ;
        for j = 1 : block_width : table_width*block_width
            j_med = j_med + 1;
            image_data_median(i_med,j_med) = uint8( median([image_data(i,j),image_data(i,j+1),image_data(i+1,j),image_data(i+1,j+1)]) );
        end
        j_med = 0;
    end
    
    % set lsb1,lsb2,lsb3 to zero
    image_data_avg = (floor(double(image_data_avg)/8)*8);
    image_data_median_a2 = (floor(double(image_data_median_a2)/8)*8);
    image_data_median_a3 = (floor(double(image_data_median_a3)/8)*8);
    image_data_median = (floor(double(image_data_median)/8)*8);
    image_data = double(image_data);
    
    % calculate euclidean distance
    distance_avg = zeros(table_height,table_width,'double');   
    distance_median_a2 = zeros(table_height,table_width,'double');
    distance_median_a3 = zeros(table_height,table_width,'double');
    distance_median = zeros(table_height,table_width,'double');
    for i = 1 : table_height
        for j = 1 : table_width
            distance_avg(i,j) = (image_data_avg(i,j)-image_data(i*block_height,j*block_width))^2+(image_data_avg(i,j)-image_data(i*block_height-1,j*block_width))^2+(image_data_avg(i,j)-image_data(i*block_height,j*block_width-1))^2+(image_data_avg(i,j)-image_data(i*block_height-1,j*block_width-1))^2;
            distance_median_a2(i,j) = (image_data_median_a2(i,j)-image_data(i*block_height,j*block_width))^2+(image_data_median_a2(i,j)-image_data(i*block_height-1,j*block_width))^2+(image_data_median_a2(i,j)-image_data(i*block_height,j*block_width-1))^2+(image_data_median_a2(i,j)-image_data(i*block_height-1,j*block_width-1))^2;
            distance_median_a3(i,j) = (image_data_median_a3(i,j)-image_data(i*block_height,j*block_width))^2+(image_data_median_a3(i,j)-image_data(i*block_height-1,j*block_width))^2+(image_data_median_a3(i,j)-image_data(i*block_height,j*block_width-1))^2+(image_data_median_a3(i,j)-image_data(i*block_height-1,j*block_width-1))^2;
            distance_median(i,j) = (image_data_median(i,j)-image_data(i*block_height,j*block_width))^2+(image_data_median(i,j)-image_data(i*block_height-1,j*block_width))^2+(image_data_median(i,j)-image_data(i*block_height,j*block_width-1))^2+(image_data_median(i,j)-image_data(i*block_height-1,j*block_width-1))^2;
        end
    end
    
    % find best method
    method_percentage_count  = zeros(1,4,'double');
    for i = 1 : table_height
        for j = 1 : table_width
            if min([distance_avg(i,j) distance_median_a2(i,j) distance_median_a3(i,j) distance_median(i,j)]) == distance_avg(i,j)
                watermark_data(i,j) = image_data_avg(i,j);
                best_method_matrix(i,j) = 1;
                method_percentage_count(1,1) = method_percentage_count(1,1) + 1;
            elseif min([distance_avg(i,j) distance_median_a2(i,j) distance_median_a3(i,j) distance_median(i,j)]) == distance_median_a2(i,j)
                watermark_data(i,j) = image_data_median_a2(i,j);
                best_method_matrix(i,j) = 2;
                method_percentage_count(1,2) = method_percentage_count(1,2) + 1;
            elseif min([distance_avg(i,j) distance_median_a2(i,j) distance_median_a3(i,j) distance_median(i,j)]) == distance_median_a3(i,j)
                watermark_data(i,j) = image_data_median_a3(i,j);
                best_method_matrix(i,j) = 3;
                method_percentage_count(1,3) = method_percentage_count(1,3) + 1;
            elseif min([distance_avg(i,j) distance_median_a2(i,j) distance_median_a3(i,j) distance_median(i,j)]) == distance_median(i,j)
                watermark_data(i,j) = image_data_median(i,j);
                best_method_matrix(i,j) = 4;
                method_percentage_count(1,4) = method_percentage_count(1,4) + 1;
            end
        end
    end
    method_percentage = method_percentage_count/double(table_height*table_width); 
    watermark_data = uint8(watermark_data);
%     fprintf('debug');
end



