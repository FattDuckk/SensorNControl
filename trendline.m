clear 
close all

load Mesh_Soft_EM_Mod_0601.mat;

%% Voxelization
FV.vertices = ver;
FV.faces = tri;
a = polygon2voxel(FV, [200 200 200], 'auto');

%% Filling the interior
% Find an interior seed point using the centroid of the vertices
seedPoint = round(mean(ver));

% Fill the interior
a_filled = imfill(a, 'holes');

% Subtract the exterior to get only the filled interior
interior = a_filled - a;

%% Skeletonization
b = bwskel(logical(interior));

% Plot the original mesh
figure;
patch(FV, 'FaceColor', [0.8, 0.8, 0.8], 'EdgeColor', 'none');
camlight; lighting gouraud;
alpha(0.5); % Make it slightly transparent for better visualization
hold on;

% Extract coordinates of the skeleton voxels and plot them
[y, x, z] = ind2sub(size(b), find(b));

% scaleFactor = [1, 1, 1]; % [scaleX, scaleY, scaleZ]+
scaleFactor = [0.95, 0.95, 0.95]; % [scaleX, scaleY, scaleZ]
translation = [-15 , -126 ,-205 ]; % [translateX, translateY, translateZ]

x = x * scaleFactor(1) + translation(1);
y = y * scaleFactor(2) + translation(2);
z = z * scaleFactor(3) + translation(3);

% centreline=[x y z]

% plot3(x, y, z, 'r.', 'MarkerSize', 10);

% Adjust view properties for better visualization
axis equal;
grid on;
xlabel('X'); ylabel('Y'); zlabel('Z');
view(3); % Set to 3D view

%%

% [pruned(:,1),pruned(:,2),pruned(:,3)]=prune_unrelated_branches(x,y,z,197,5)
% 
% plot3(pruned(:,1), pruned(:,2), pruned(:,3), 'r.', 'MarkerSize', 10);
%%
threshold = 2.0;
adj_matrix = constructAdjMatrix([x y z], threshold);

% % Perform BFS on the constructed graph starting from the first point
% bfs(adj_matrix, 197, centreline);


%%

[pruned(:,1),pruned(:,2),pruned(:,3)]=pruneOffBranch(adj_matrix, x, y, z, 197, 5);
plot3(pruned(:,1), pruned(:,2), pruned(:,3), 'r.', 'MarkerSize', 10);

%%
% Separate your centerline data into x, y, and z
% Separate your centerline data into x, y, and z
centerline=pruned
% Separate your centerline data into x, y, and z
x = centerline(:, 1);
y = centerline(:, 2);
z = centerline(:, 3);

% Parameterize the curve by its cumulative chordal arclength
t = [0; cumsum(sqrt(diff(x).^2 + diff(y).^2 + diff(z).^2))];
t = t / t(end); % normalize to [0, 1]

% Fit cubic B-splines using least-squares approximation
num_knots = 20;  % Adjust this number for desired smoothness
sp_x = spap2(num_knots,4,t,x);
sp_y = spap2(num_knots,4,t,y);
sp_z = spap2(num_knots,4,t,z);

% Evaluate B-spline at a set of points for plotting
tt = linspace(0, 1, 1000);
spline_x = fnval(sp_x, tt);
spline_y = fnval(sp_y, tt);
spline_z = fnval(sp_z, tt);

% Plot
figure;
plot3(x, y, z, 'o-', 'DisplayName', 'Original Centerline');
hold on;
plot3(spline_x, spline_y, spline_z,'ro', 'DisplayName', 'Cubic B-spline');
legend;
grid on;
title('Cubic B-spline Smoothing of 3D Centerline');
xlabel('X');
ylabel('Y');
zlabel('Z');

%%
x = centerline(:, 1);
y = centerline(:, 2);
z = centerline(:, 3);

% Parameterize the curve by its cumulative chordal arclength
t = [0; cumsum(sqrt(diff(x).^2 + diff(y).^2 + diff(z).^2))];
t = t / t(end); % normalize to [0, 1]

% Fit cubic B-splines using least-squares approximation
num_knots = 20;  % Adjust this number for desired smoothness
sp_x = spap2(num_knots,4,t,x);
sp_y = spap2(num_knots,4,t,y);
sp_z = spap2(num_knots,4,t,z);

% Evaluate B-spline at a set of points for plotting
tt = linspace(0, 1, 10);
spline_x = fnval(sp_x, tt);
spline_y = fnval(sp_y, tt);
spline_z = fnval(sp_z, tt);

% Plot

% plot3(x, y, z, 'o-', 'DisplayName', 'Original Centerline');
hold on;
plot3(spline_x, spline_y, spline_z,'ro', 'DisplayName', 'Cubic B-spline');
legend;
grid on;
title('Cubic B-spline Smoothing of 3D Centerline');
xlabel('X');
ylabel('Y');
zlabel('Z');

%%



%%

function [reindexed_adj, reindexed_x, reindexed_y, reindexed_z] = reindexByBFS(adj_matrix, x, y, z, start_node)
    n = size(adj_matrix, 1);
    visited = false(1, n);
    
    bfs_order = [];
    queue = start_node;
    visited(start_node) = true;
    
    while ~isempty(queue)
        current_node = queue(1);
        bfs_order(end+1) = current_node;
        queue(1) = [];
        
        neighbors = find(adj_matrix(current_node, :));
        for ii = 1:length(neighbors)
            neighbor = neighbors(ii);
            if ~visited(neighbor)
                visited(neighbor) = true;
                queue(end+1) = neighbor;  % enqueue
            end
        end
    end
    
    % Create a mapping for reindexing
    mapping = zeros(1, n);
    for new_idx = 1:length(bfs_order)
        old_idx = bfs_order(new_idx);
        mapping(old_idx) = new_idx;
    end
    
    % Reindex adjacency matrix
    reindexed_adj = adj_matrix;
    reindexed_adj = reindexed_adj(mapping, :);
    reindexed_adj = reindexed_adj(:, mapping);
    
    % Reindex coordinates
    reindexed_x = x(bfs_order);
    reindexed_y = y(bfs_order);
    reindexed_z = z(bfs_order);
end

%%
function [branch_x, branch_y, branch_z] = pruneOffBranch(adj_matrix, x, y, z, start_node, end_node)
    n = size(adj_matrix, 1);
    visited = false(1, n);
    predecessor = zeros(1, n);
    
    % BFS to determine predecessors
    queue = start_node;
    visited(start_node) = true;
    found = false;
    while ~isempty(queue)
        current_node = queue(1);
        queue(1) = [];
        
        neighbors = find(adj_matrix(current_node, :));
        for ii = 1:length(neighbors)
            neighbor = neighbors(ii);
            if ~visited(neighbor)
                visited(neighbor) = true;
                predecessor(neighbor) = current_node;
                queue(end+1) = neighbor;  % enqueue
                
                if neighbor == end_node
                    found = true;
                    break;
                end
            end
        end
        if found
            break;
        end
    end
    
    % If there's no path from start_node to end_node
    if ~found
        branch_x = [];
        branch_y = [];
        branch_z = [];
        return;
    end
    
    % Reconstruct the main branch using predecessors
    main_branch = [];
    node = end_node;
    while node ~= start_node
        main_branch = [node, main_branch];
        node = predecessor(node);
    end
    main_branch = [start_node, main_branch];
    
    % Extract coordinates of the nodes in the main branch
    branch_x = x(main_branch);
    branch_y = y(main_branch);
    branch_z = z(main_branch);
end


%%
function adj_matrix = constructAdjMatrix(coords, threshold)
    num_points = size(coords, 1);
    adj_matrix = zeros(num_points, num_points);
    
    for i = 1:num_points
        for j = i+1:num_points
            distance = norm(coords(i,:) - coords(j,:));
            if distance < threshold
                adj_matrix(i,j) = 1;
                adj_matrix(j,i) = 1;  % Since it's undirected
            end
        end
    end
end

%%
function bfs(adj_matrix, start_node, coords)
    num_nodes = size(adj_matrix, 1);
    visited = false(1, num_nodes);
    queue = [];

    visited(start_node) = true;
    queue = [queue, start_node];

    % Setup the plot
    figure;
    plot3(coords(:,1), coords(:,2), coords(:,3), 'o', 'MarkerSize', 8, 'Color', 'blue');
    hold on;
    title('BFS Traversal');
    xlabel('x');
    ylabel('y');
    zlabel('z');
    
    % Draw edges based on adjacency matrix
    for i = 1:num_nodes
        for j = 1:num_nodes
            if adj_matrix(i,j)
                plot3([coords(i,1), coords(j,1)],[coords(i,2), coords(j,2)],[coords(i,3), coords(j,3)], 'k-');
            end
        end
    end

    while ~isempty(queue)
        current_node = queue(1);
        fprintf('Visited %d\n', current_node);

        % Highlight the currently visited node in red
        plot3(coords(current_node,1), coords(current_node,2), coords(current_node,3), 'o', 'MarkerSize', 8, 'Color', 'red');
        pause(0.5);  % Pause for half a second

        for i = 1:num_nodes
            if adj_matrix(current_node, i) && ~visited(i)
                visited(i) = true;
                queue = [queue, i];
            end
        end

        queue(1) = [];
    end
end


%%

