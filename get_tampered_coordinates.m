function [row_start_coordinate,row_end_coordinate,col_start_coordinate,col_end_coordinate] = get_tampered_coordinates(tampered_row,tampered_col,image_row,image_col,location)
%UNTITLED14 此处显示有关此函数的摘要
%   此处显示详细说明
%     location 定义：
%     1.center
%     2.top
%     3.left
    if location == 1
        row_start_coordinate = image_row/2 - tampered_row/2 + 1;
        row_end_coordinate = image_row/2 + tampered_row/2;
        col_start_coordinate = image_col/2 - tampered_col/2 + 1;
        col_end_coordinate = image_col/2 + tampered_col/2;
    end
    if mod(row_start_coordinate,2) == 0
        row_start_coordinate = row_start_coordinate - 1;
        row_end_coordinate = row_end_coordinate - 1; 
    end
    if mod(col_start_coordinate,2) == 0
        col_start_coordinate = col_start_coordinate - 1;
        col_end_coordinate = col_end_coordinate - 1; 
    end
end

