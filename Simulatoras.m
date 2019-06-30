function Simulator()
    % Construct the Quadcopter System.
    state  = setup_state();
    state  = setup_paint(state);

    % Simulate the Quadcopter.
    for i = 1:1000
        % Apply control.
        state  = apply_control(state);
                
        % Compute all state variables.
        state  = update_acceleration(state);
        state  = update_omega(state);
        state  = update_omegadot(state);
        
        % Advance state by 1 step.
        state  = advance(state);
        
        % Visualize the current state.
         paint(state);
    end
end

function state = setup_state()
% Physical constants.
g = 9.81;      % gravitational acceleration m/sec^2
m = 0.8;       % mass in kg
L = 0.25;      % length of arms in m

k = 3e-3;      %
kb = 1e-7;     % Drag Coefficient
kd = 0.25;     % Drag Constant derived by using air flow, propeller sizes and air drag coefficient.
Ix = 5e-3;     % Moment of Inertia in X Euclidian Axis
Iy = 5e-3;     % Moment of Inertia in Y Euclidean Axis
Iz = 10e-3;    % Moment of Inertia in Z Euclidean Axis
dt = 1e-2;     % Simulation Step Size in Seconds

% state parameters
x         = [0; 0; 50];    % x, y, z location of the quadcopter Center of Gravity.
R         = zeros(3, 3);   % Rotation Matrix from Euclidian Linear to roll, pitch and yaw.
W         = zeros(3, 3);   % Translation Matrix from Euclidean roll, pitch and Yaw to Body Frame.
xdot      = zeros(3, 1);   % Velocity in x, y and z directions.
a         = zeros(3, 1);   % acceleration in x, y and z directiions.
omega     = zeros(3, 1);   % angular velocity around x, y and z axis.
omegadot  = zeros(3, 1);   % angular acceleration around x, y and z axis.
theta     = zeros(3, 1);   % roll pitch and yaw of the quadcopter.

% add some initial thetadot
thetadot  = rand(3, 1)*5;    % angular velocities of roll, pitch and yaw of the quadcopter.

% control parameters
integral  = zeros(3, 1);   % Integral of the out over time for integral component of the pid controller
error     = zeros(3, 1);   % reference signal based on the pid product of out and pid values.
tau       = zeros(3, 1);   % torques generated by the control system.

P = 9;                     % sample pid- proporional value.
I = 0;                     % sample pid - integral value.
D = 5;                     % sample pid - derivative value.
pid = [P; I; D];           % pid values for the state variable.

% graphics object
t = hgtransform;

% Struct given to the controller. Controller may store its persistent state in it.
state = struct('dt',       dt,       ...
               'Ix',       Ix,       ...
               'Iy',       Iy,       ...
               'Iz',       Iz,       ...
               'k',        k,        ...
               'kd',       kd,       ...
               'D',        D,        ...
               'P',        P,        ...
               'I',        I,        ...
               'L',        L,        ...
               'kb',       kb,       ...
               'm',        m,        ...
               'g',        g,        ...
               'x',        x,        ...
               'a',        a,        ...
               'R',        R,        ...
               'W',        W,        ...
               't',        t,        ...
               'pid',      pid,      ...
               'xdot',     xdot,     ...
               'omega',    omega,    ...
               'omegadot', omegadot, ...
               'tau',      tau,      ...
               'theta',    theta,    ...
               'thetadot', thetadot, ...
               'integral', integral, ...
               'error',    error);
end

% Update Translation between Body and Euclidian Frames.
function state = update_W(state)
phi   = state.theta(1);
theta = state.theta(2);
W = [
     1, 0,         -sin(theta)
     0, cos(phi),  cos(theta)*sin(phi)
     0, -sin(phi), cos(theta)*cos(phi)
     ];
state.W = W;
end

function state = setup_paint(state)
grid off
shading interp
view(3)

% Base
[x1,y1,z1] = cylinder([0.3 0.3 0 0 0 0 0]);
% Arms
[x2,y2,z2] = cylinder(0.05);
% Motors
[x3,y3,z3] = cylinder([0.2 0.2 0 0]);

h(1) = surface(x1,y1,0.2*z1,'FaceColor','black', 'edgecolor','none');
h(2) = surface(x1,y1,-0.2*z1,'FaceColor','white', 'edgecolor','none');
h(3) = surface(z2,x2,y2,'FaceColor','blue', 'edgecolor','none');
h(4) = surface(-z2,x2,y2,'FaceColor','cyan', 'edgecolor','none');
h(5) = surface(y2,z2,x2,'FaceColor','magenta', 'edgecolor','none');
h(6) = surface(y2,-z2,x2,'FaceColor','yellow', 'edgecolor','none');
h(7) = surface(x3-1, y3, 0.2*z3,'FaceColor','green', 'edgecolor','none');
h(8) = surface(x3-1, y3, -0.2*z3,'FaceColor','red', 'edgecolor','none');
h(9) = surface(x3+1, y3, 0.2*z3,'FaceColor','green', 'edgecolor','none');
h(10) = surface(x3+1, y3, -0.2*z3,'FaceColor','red', 'edgecolor','none');
h(11) = surface(x3, y3-1, 0.2*z3,'FaceColor','green', 'edgecolor','none');
h(12) = surface(x3, y3-1, -0.2*z3,'FaceColor','red', 'edgecolor','none');
h(13) = surface(x3, y3+1, 0.2*z3,'FaceColor','green', 'edgecolor','none');
h(14) = surface(x3, y3+1, -0.2*z3,'FaceColor','red', 'edgecolor','none');
set(h, 'Parent', state.t);
Txyz = makehgtform('translate', state.x);
set(state.t, 'Matrix', Txyz);
end



% Compute rotation matrix for a set of angles.
function state = update_R(state)
phi   = state.theta(1);
theta = state.theta(2);
psi   = state.theta(3);
R = [
     cos(phi)*cos(theta), cos(phi)*sin(theta)*sin(psi)-cos(psi)*sin(phi), sin(phi)*sin(psi)+cos(phi)*cos(psi)*sin(theta)
     cos(theta)*sin(phi), cos(phi)*cos(psi)+sin(phi)*sin(theta)*sin(psi), cos(psi)*sin(phi)*sin(theta)-cos(phi)*sin(psi)
     -sin(theta),         cos(theta)*sin(psi),                            cos(theta)*cos(phi)
     ];
state.R = R;
end

function state = apply_control(state)
    Ix = state.Ix;
    Iy = state.Iy;
    Iz = state.Iz;
    k  = state.k;
    L  = state.L;
    kb  = state.kb;
    in = zeros(4, 1);
    
    % Compute total thrust.
    state.thrust = state.m*state.g/...
        (cos(state.theta(1))*cos(state.theta(2)));
     
    
    % Compute error.
    state.error = state.pid(1)*state.theta ...
        + state.pid(2)*state.integral + state.pid(3)*state.thetadot;
    
    e1  = state.error(1);
    e2  = state.error(2);
    e3  = state.error(3);
    
    % Update controller state.
    state.integral = state.integral + state.theta * state.dt;
    
    % Optional: Prevent wind-up.
    if max(abs(state.integral)) > 0.1*state.dt
        % "wind-up".
        state.integral = zeros(3, 1);
    end
    
    % Compute input.
    in(1) = state.thrust/(4*k) - e1*Ix/(2*k*L)              - e3*Iz/(4*kb);
    in(2) = state.thrust/(4*k)              - e2*Iy/(2*k*L) + e3*Iz/(4*kb);
    in(3) = state.thrust/(4*k) + e1*Ix/(2*k*L)              - e3*Iz/(4*kb);
    in(4) = state.thrust/(4*k)              + e2*Iy/(2*k*L) + e3*Iz/(4*kb);
    
    state.tau = [
        L*k*(in(1) - in(3))
        L*k*(in(2) - in(4))
        kb* (in(1) - in(2) + in(3) - in(4))
    ];
end

% Compute acceleration in Euclidian/Inertial reference frame.
function state = update_acceleration(state)
    state = update_R(state);
    T = state.R * [0; 0; state.thrust];
    state.a = [0; 0; -state.g] + T/state.m - state.kd*state.xdot/state.m;
end

% Convert derivatives of the theta to angular velocity omega.
function state = update_omega(state)
    state = update_W(state);
    state.omega = state.W * state.thetadot;
end

% Compute angular acceleration in body frame.
function state = update_omegadot(state)
    tau = state.tau;
    I = diag([state.Ix; state.Iy; state.Iz]);
    state.omegadot = I\(tau - cross(state.omega, I*state.omega));
end

function state = advance(state)

    % TODO
    state.omega = state.omega + state.omegadot*state.dt;
    state = update_thetadot(state);
    % TODO
    state.theta  = state.theta + state.thetadot*state.dt;
    
    % TODO
    state.xdot = state.xdot + state.a*state.dt;
    % TODO
    state.x = state.x + state.xdot*state.dt;
end

% Convert omega to roll, pitch, and yaw derivatives.
function state = update_thetadot(state)
    state = update_W(state);
    % TODO
    state.thetadot = state.W \ state.omega;
end

function paint(state)

    Rx  = makehgtform('xrotate', state.theta(1));
    
   
    Ry  = makehgtform('yrotate', state.theta(2));
    
    
    Rz  = makehgtform('zrotate', state.theta(3));
    

    Txyz  = makehgtform('translate', state.x); 
    
    set(state.t, 'Matrix', Txyz*Rz*Ry*Rx);       
    pause(state.dt)                              % delay by simulation step for close to realistic scenario.    
    drawnow                                      
end