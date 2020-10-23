module m_spindynamics
implicit none
contains
subroutine spindynamics(mag_lattice,io_simu,ext_param,Hams)
use m_basic_types, only : vec_point
use m_derived_types, only : t_cell,io_parameter,simulation_parameters,point_shell_Operator
use m_derived_types, only : lattice,number_different_order_parameters
use m_modes_variables, only : point_shell_mode
!use m_torques, only : get_torques
use m_lattice, only : my_order_parameters
use m_measure_temp
use m_topo_commons
use m_update_time
use m_randist
use m_constants, only : pi,k_b,hbar
use m_eval_Beff
use m_write_spin
use m_energyfield, only : get_Energy_distrib
use m_createspinfile
use m_dyna_utils
use m_user_info
use m_excitations
use m_solver_commun
use m_topo_sd
use m_forces
use m_plot_FFT
use m_solver_order
use m_io_files_utils
use m_tracker
use m_print_Beff
use omp_lib
use m_precision
use m_Htype_gen
use m_Beff_H

! input
type(lattice), intent(inout) :: mag_lattice
type(io_parameter), intent(in) :: io_simu
type(simulation_parameters), intent(in) :: ext_param
class(t_H), intent(in) :: Hams(:)
! internal
logical :: gra_log,io_stochafield
integer :: i,j,gra_freq,i_loop,input_excitations
! lattices that are used during the calculations
type(lattice)                         :: lat_1,lat_2
! pointers specific for the modes
type(vec_point),target,allocatable,dimension(:,:) :: mode_excitation_field,lattice_ini_excitation_field

!intermediate values for dynamics
real(8),allocatable                     :: Dmag(:,:,:),Dmag_int(:,:)
real(8),allocatable,dimension(:),target :: Beff(:)
real(8),pointer,contiguous              :: Beff_v(:,:)


! dummys
real(kind=8) :: qeuler,q_plus,q_moins,vortex(3),Mdy(3),Edy,Eold,dt
real(kind=8) :: Mx,My,Mz,vx,vy,vz,check(2),test_torque,Einitial,ave_torque
real(kind=8) :: dumy(5),security(2)
real(kind=8) :: timestep_int,real_time,h_int(3),damping,E_int(3)
real(kind=8) :: kt,ktini,ktfin
real(kind=8) :: time
integer :: iomp,N_cell,N_loop,duration,Efreq
!integer :: io_test
!! switch that controls the presence of magnetism, electric fields and magnetic fields
logical :: i_excitation
logical :: used(number_different_order_parameters)
! dumy
logical :: said_it_once,gra_topo

time=0.0d0
input_excitations=0

OPEN(7,FILE='EM.dat',action='write',status='replace',form='formatted')
      Write(7,'(20(a,2x))') '# 1:step','2:real_time','3:E_av','4:M', &
     &  '5:Mx','6:My','7:Mz','8:vorticity','9:vx', &
     &  '10:vy','11:vz','12:qeuler','13:q+','14:q-','15:T=', &
     &  '16:Tfin=','17:Ek=','18:Hx','19:Hy=','20:Hz='

! check the convergence
open(8,FILE='convergence.dat',action='write',form='formatted')

! prepare the matrices for integration

call rw_dyna(timestep_int,damping,Efreq,duration)
N_cell=product(mag_lattice%dim_lat)
Call mag_lattice%used_order(used)
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! Select the propagators and the integrators
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call select_propagator(ext_param%ktini%value,N_loop)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! Create copies of lattice with order-parameter for intermediary states
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Call mag_lattice%copy(lat_1) 
Call mag_lattice%copy(lat_2) 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! associate pointer for the topological charge, vorticity calculations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call user_info(6,time,'topological operators',.false.)

!UPDATE
call get_size_Q_operator(mag_lattice)
call associate_Q_operator(lat_1%ordpar%all_l_modes,mag_lattice%boundary,shape(mag_lattice%ordpar%l_modes))

call user_info(6,time,'done',.true.)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! allocate the element of integrations and associate the pointers to them
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

allocate(Beff(mag_lattice%M%dim_mode*N_cell),source=0.0d0)
Beff_v(1:mag_lattice%M%dim_mode,1:N_cell)=>Beff

allocate(Dmag(mag_lattice%M%dim_mode,N_cell,N_loop),source=0.0d0) 
allocate(Dmag_int(mag_lattice%M%dim_mode,N_cell),source=0.0d0) 


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! start the simulation
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

gra_log=io_simu%io_Xstruct
io_stochafield=io_simu%io_Tfield
gra_freq=io_simu%io_frequency
gra_topo=io_simu%io_topo
ktini=ext_param%ktini%value
ktfin=ext_param%ktfin%value
kt=ktini
Eold=100.0d0
real_time=0.0d0
Einitial=0.0d0
h_int=ext_param%H_ext%value
E_int=ext_param%E_ext%value
said_it_once=.False.
security=0.0d0

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! initialize the simulation
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Call mag_lattice%copy_val_to(lat_1)

Edy=energy_all(Hams,mag_lattice)

write(6,'(a,2x,E20.12E3)') 'Initial Total Energy (eV)',Edy/real(N_cell)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! part of the excitations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call set_excitations('input',i_excitation,input_excitations)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! do we use the update timestep
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call init_update_time('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! initialize the different torques
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!call get_torques('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! check if a magnetic texture should be tracked
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
if (io_simu%io_tracker) call init_tracking(mag_lattice)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! beginning of the
do j=1,duration
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   !   call init_temp_measure(check,check1,check2,check3)
    
    call truncate(lat_1,used)
    qeuler=0.0d0
    q_plus=0.0d0
    q_moins=0.0d0
    vx=0.0d0
    vy=0.0d0
    vz=0.0d0
    Mx=0.0d0
    My=0.0d0
    Mz=0.0d0
    Edy=0.0d0
    Mdy=0.0d0
    vortex=0.0d0
    test_torque=0.0d0
    ave_torque=0.0d0
    Mdy=0.0d0
    test_torque=0.0d0
    dt=timestep_int
    !why is this outside of the integration order loop? time changes there
    call update_ext_EM_fields(real_time,check)
    
    !
    ! loop over the integration order
    !
    do i_loop=1,N_loop
      !get actual dt from butchers table
      !dt=get_dt_mode(timestep_int,i_loop)
    
      ! loop that get all the fields
      if (i_excitation) then
          do iomp=1,N_cell
            !smarter to just copy relevant order parameters around, or even point all to the same array
              call update_EMT_of_r(iomp,mag_lattice)
              call update_EMT_of_r(iomp,lat_1)
          enddo
      endif
   
    !update mag
      !get effective field on magnetic lattice
      Call get_B(Hams,lat_1,Beff)
      !do integration
      ! Be carefull the sqrt(dt) is not included in BT_mag(iomp),D_T_mag(iomp) at this point. It is included only during the integration
      Call get_propagator_field(Beff_v,damping,lat_1%M%modes_v,Dmag(:,:,i_loop))
      Call get_Dmag_int(Dmag,i_loop,N_loop,Dmag_int)
      lat_2%M%modes_v=get_integrator_field(mag_lattice%M%modes_v,Dmag_int,dt)
    !copy mag 
      Call lat_2%M%copy_val(lat_1%M)
    enddo
    !!!!!!!!!!!!!!! copy the final configuration in my_lattice
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    Call lat_2%M%copy_val(mag_lattice%M)
    call truncate(mag_lattice,used)
    
    !
    !!!!!! Measure the temperature if the users wish
    !
    Edy=energy_all(Hams,mag_lattice)
    Mdy=sum(mag_lattice%M%modes_v,2) !works only for one M in unit cell
    !check this?
    do iomp=1,N_cell
        dumy=get_charge(iomp)
        q_plus=q_plus+dumy(1)/pi(4.0d0)
        q_moins=q_moins+dumy(2)/pi(4.0d0)
        vx=vx+dumy(3)
        vy=vy+dumy(4)
        vz=vz+dumy(5)
    enddo
    vortex=(/vx,vy,vz/)/3.0d0/sqrt(3.0d0)
    Edy=Edy/real(N_cell)
    Mdy=Mdy/real(N_cell)
    
    !if (dabs(check(2)).gt.1.0d-8) call get_temp(security,check,kt)
    
    if (io_simu%io_tracker) then
      if (mod(j-1,gra_freq).eq.0) call plot_tracking(j/gra_freq,lat_1,Hams)
    endif
    
    if (mod(j-1,Efreq).eq.0) then
        Write(7,'(I6,18(E20.12E3,2x),E20.12E3)') j,real_time,Edy, &
         &   norm2(Mdy),Mdy,norm2(vortex),vortex,q_plus+q_moins,q_plus,q_moins, &
         &   kT/k_B,(security(i),i=1,2),H_int
        write(8,'(I10,3x,3(E20.12E3,3x))') j,Edy,test_torque,ave_torque
    endif
    
    ! security in case of energy increase in SD and check for convergence
    if (((damping*(Edy-Eold).gt.1.0d-10).or.(damping*(Edy-Einitial).gt.1.0d-10)).and.(kt.lt.1.0d-10).and.(.not.said_it_once)) then
        write(6,'(a)') 'WARNING: the total energy or torque is increasing for non zero damping'
        write(6,'(a)') 'this is not allowed by theory'
        write(6,'(a)') 'please reduce the time step'
        said_it_once=.True.
    endif
    Eold=Edy
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!! plotting with graphical frequency
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    if(mod(j-1,gra_freq)==0)then
        if (io_simu%io_Beff) call print_Beff(j/gra_freq,Beff_v)
    
        if (io_simu%io_Energy_Distrib) &
           &  call get_Energy_distrib(j/gra_freq,mag_lattice%ordpar%all_l_modes) !CHANGE!!!
    
        if(gra_log) then
            call CreateSpinFile(j/gra_freq,mag_lattice%M%all_l_modes)
            call WriteSpinAndCorrFile(j/gra_freq,mag_lattice%M%all_l_modes,'SpinSTM_')
            write(6,'(a,3x,I10)') 'wrote Spin configuration and povray file number',j/gra_freq
            write(6,'(a,3x,f14.6,3x,a,3x,I10)') 'real time in ps',real_time/1000.0d0,'iteration',j
        endif
        if(gra_topo) Call get_charge_map(j/gra_freq)
    
        if (io_simu%io_Force) call forces(j/gra_freq,lat_1%ordpar%all_l_modes,mag_lattice%dim_mode,mag_lattice%areal)
    
        if(io_simu%io_fft_Xstruct) call plot_fft(mag_lattice%ordpar%all_l_modes,-1.0d0,mag_lattice%areal,mag_lattice%dim_lat,mag_lattice%boundary,mag_lattice%dim_mode,j/gra_freq)
    endif
    
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! update timestep
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    call update_time(timestep_int,Beff_v,damping)
    
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ! reinitialize T variables
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!
    check(1)=0.0d0
    check(2)=0.0d0
    
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    !!!!!!!!!!!!!!! end of a timestep
    real_time=real_time+timestep_int !increment time counter
enddo 

!!!!!!!!!!!!!!! end of iteration
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
close(7)
close(8)

if ((dabs(check(2)).gt.1.0d-8).and.(kt/k_B.gt.1.0d-5)) then
    write(6,'(a,2x,f16.6)') 'Final Temp (K)', check(1)/check(2)/2.0d0/k_B
    write(6,'(a,2x,f14.7)') 'Kinetic energy (meV)', (check(1)/check(2)/2.0d0-kT)/k_B*1000.0d0
else
    write(6,'(a)') 'the temperature measurement is not possible'
endif

end subroutine spindynamics

end module
