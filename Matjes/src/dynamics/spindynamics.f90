subroutine spindynamics(mag_lattice,mag_motif,io_simu,ext_param)
use m_basic_types, only : vec_point
use m_derived_types, only : lattice,cell,io_parameter,simulation_parameters,point_shell_Operator,point_shell_mode
use m_torques, only : get_torques
use m_lattice, only : my_order_parameters
use m_eval_BTeff
use m_measure_temp
use m_topo_commons
use m_update_time, only : update_time,get_dt_LLG,init_update_time
use m_vector, only : cross,norm,norm_cross
use m_randist
use m_constants, only : pi,k_b,hbar
use m_eval_Beff
use m_write_spin
use m_energyfield, only : get_Energy_distrib,get_Energy_distrib_line
use m_createspinfile
use m_local_energy
use m_dyna_utils
use m_energy_commons, only : get_E_line
use m_internal_fields_commons, only : get_B_line
use m_user_info
use m_excitations
use m_operator_pointer_utils
use m_solver_commun
use m_topo_sd
implicit none
! input
type(lattice), intent(inout) :: mag_lattice
type(cell), intent(in) :: mag_motif
type(io_parameter), intent(in) :: io_simu
type(simulation_parameters), intent(in) :: ext_param
! internal
logical :: gra_log,io_stochafield
integer :: i,j,l,h,gra_freq
! lattices that are used during the calculations
real(kind=8),allocatable,dimension(:,:,:,:,:) :: spinafter
real(kind=8),allocatable,dimension(:,:) :: D_mode,D_T,Bini,BT
type(vec_point),allocatable,dimension(:) :: all_mode_1,all_mode_2
! pointers specific for the modes
type(vec_point),allocatable,dimension(:) :: mode_temp,mode_Efield,mode_Hfield,mode_excitation_field
type(vec_point),allocatable,dimension(:,:) :: mode_magnetic,mode_disp
type(vec_point),target,allocatable,dimension(:) :: D_mode_mag,D_T_mag,B_mag,BT_mag
type(vec_point),target,allocatable,dimension(:) :: D_mode_disp,D_T_disp,B_disp,BT_disp
! lattice pf pointer that will be used in the simulation
type(point_shell_Operator), allocatable, dimension(:) :: E_line,B_line_1,B_line_2
type(point_shell_mode), allocatable, dimension(:) :: mode_E_column,mode_B_column_1,mode_B_column_2
! dummys
real(kind=8) :: qeuler,q_plus,q_moins,vortex(3),Mdy(3),Edy,check1,check2,Eold,check3,Et,dt
real(kind=8) :: Mx,My,Mz,vx,vy,vz,check(2),test_torque,Einitial,ave_torque
real(kind=8) :: dumy(5),security(2)
real(kind=8) :: timestep_int,real_time,h_int(3),damping,E_int(3)
real(kind=8) :: kt,ktini,ktfin
real(kind=8) :: time
integer :: iomp,shape_lattice(4),shape_spin(4),N_cell,N_loop,duration,Efreq
!! switch that controls the presence of magnetism, electric fields and magnetic fields
logical :: i_magnetic,i_temperature,i_mode,i_Efield,i_Hfield,i_excitation,i_displacement
! dumy
logical :: said_it_once,gra_topo


OPEN(7,FILE='EM.dat',action='write',status='replace',form='formatted')
      Write(7,'(20(a,2x))') '# 1:step','2:real_time','3:E_av','4:M', &
     &  '5:Mx','6:My','7:Mz','8:vorticity','9:vx', &
     &  '10:vy','11:vz','12:qeuler','13:q+','14:q-','15:T=', &
     &  '16:Tfin=','17:Ek=','18:Hx','19:Hy=','20:Hz='

! check the convergence
open(8,FILE='convergence.dat',action='write',form='formatted')

! prepare the matrices for integration

call rw_dyna(shape_lattice(1:3),mag_lattice,timestep_int,damping,Efreq,duration)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! Select the propagators and the integrators
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

call select_propagator(ext_param%ktini%value,N_loop)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! Allocate the matrix of after spin and the pointers associated to it
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

allocate(all_mode_1(N_cell),all_mode_2(N_cell))
allocate(spinafter(mag_lattice%dim_mode,shape_lattice(1),shape_lattice(2),shape_lattice(3),shape_lattice(4)))

shape_spin=shape_lattice
spinafter=0.0d0

call associate_pointer(all_mode_1,mag_lattice)
call associate_pointer(all_mode_2,spinafter)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! allocate the pointers for the B-field and the energy
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

time=0.0d0
call user_info(6,time,'associate H_line, B_line and S_line',.true.)

allocate(E_line(N_cell),B_line_1(N_cell),B_line_2(N_cell))
allocate(mode_E_column(N_cell),mode_B_column_1(N_cell),mode_B_column_2(N_cell))

call get_E_line(E_line,mode_E_column,all_mode_1)

call get_B_line(B_line_1,mode_B_column_1,all_mode_1)
call get_B_line(B_line_2,mode_B_column_2,all_mode_2)

if (io_simu%io_Energy_Distrib) then
   write(6,'(a)') 'setting up energy distribution'
   call get_Energy_distrib_line(all_mode_1)
endif

call user_info(6,time,'done - ready to start calculations',.true.)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! associate pointer for the topological charge, vorticity calculations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call user_info(6,time,'topological operators',.false.)

call get_size_Q_operator(mag_lattice)

call associate_Q_operator(all_mode_1,mag_lattice%boundary,shape_spin)

call user_info(6,time,'done',.true.)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! allocate the element of integrations and associate the pointers to them
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
allocate(D_mode(mag_lattice%dim_mode,N_cell),D_T(mag_lattice%dim_mode,N_cell))
D_mode=0.0d0
D_T=0.0d0

allocate(Bini(mag_lattice%dim_mode,N_cell),BT(mag_lattice%dim_mode,N_cell))
Bini=0.0d0
BT=0.0d0

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! associate pointers only for the magnetization or local modes
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
i_magnetic=.false.
i_temperature=.false.
i_mode=.false.
i_Efield=.false.
i_Hfield=.false.

! magnetization
do i=1,size(my_order_parameters)
  if ('magnetic'.eq.trim(my_order_parameters(i)%name)) then
   allocate(mode_magnetic(N_cell,N_loop),D_mode_mag(N_cell),D_T_mag(N_cell),B_mag(N_cell),BT_mag(N_cell))
   do j=1,N_loop
     call dissociate(mode_magnetic(:,j),N_cell)
     if (j.eq.1) call associate_pointer(mode_magnetic(:,j),all_mode_1,'magnetic',i_magnetic)
     if (j.eq.2) call associate_pointer(mode_magnetic(:,j),all_mode_2,'magnetic',i_magnetic)
   enddo

   call dissociate(D_mode_mag,N_cell)
   call associate_pointer(D_mode_mag,D_mode,'magnetic',i_magnetic)

   call dissociate(D_T_mag,N_cell)
   call associate_pointer(D_T_mag,D_T,'magnetic',i_magnetic)

   call dissociate(B_mag,N_cell)
   call associate_pointer(B_mag,Bini,'magnetic',i_magnetic)

   call dissociate(BT_mag,N_cell)
   call associate_pointer(BT_mag,BT,'magnetic',i_magnetic)

   exit
  endif
enddo

! temperature
do i=1,size(my_order_parameters)
  if ('temperature'.eq.trim(my_order_parameters(i)%name)) then
   allocate(mode_temp(N_cell))
   call dissociate(mode_temp,N_cell)
   call associate_pointer(mode_temp,all_mode_1,'temperature',i_temperature)

   exit
  endif
enddo

! magnetic field
do i=1,size(my_order_parameters)
  if ('Bfield'.eq.trim(my_order_parameters(i)%name)) then
   allocate(mode_Hfield(N_cell))
   call dissociate(mode_Hfield,N_cell)
   call associate_pointer(mode_Hfield,all_mode_1,'Bfield',i_Hfield)

   exit
  endif
enddo

! Electric field
do i=1,size(my_order_parameters)
  if ('Efield'.eq.trim(my_order_parameters(i)%name)) then
   allocate(mode_Efield(N_cell))
   call dissociate(mode_Efield,N_cell)
   call associate_pointer(mode_Efield,all_mode_1,'Efield',i_Efield)

   exit
  endif
enddo

! atomic displacements
do i=1,size(my_order_parameters)
  if ('displacement'.eq.trim(my_order_parameters(i)%name)) then
   allocate(mode_disp(N_cell,N_loop),D_mode_disp(N_cell),D_T_disp(N_cell),B_disp(N_cell),BT_disp(N_cell))
   do j=1,N_loop
     call dissociate(mode_magnetic(:,j),N_cell)
     if (j.eq.1) call associate_pointer(mode_disp(:,j),all_mode_1,'displacement',i_displacement)
     if (j.eq.2) call associate_pointer(mode_disp(:,j),all_mode_2,'displacement',i_displacement)
   enddo

   call dissociate(D_mode_disp,N_cell)
   call associate_pointer(D_mode_disp,D_mode,'displacement',i_displacement)

   call dissociate(D_T_disp,N_cell)
   call associate_pointer(D_T_disp,D_T,'displacement',i_displacement)

   call dissociate(B_disp,N_cell)
   call associate_pointer(B_disp,Bini,'displacement',i_displacement)

   call dissociate(BT_disp,N_cell)
   call associate_pointer(BT_disp,BT,'displacement',i_displacement)

   exit
  endif
enddo

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
! part of the excitations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call get_excitations('input',i_excitation)
! allocate the field on which the excitation occurs
if (i_excitation) then
   allocate(mode_excitation_field(N_cell))
   call dissociate(mode_excitation_field,N_cell)

   call associate_excitation(mode_excitation_field,all_mode_1,my_order_parameters)
endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! do we use the update timestep
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call init_update_time('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! initialize the difference torques
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call get_torques('input')

call init_temp_measure(check,check1,check2,check3)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! beginning of the
do j=1,duration
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

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
   l=l+1
   h=h+1
   BT=0.0d0
   Bini=0.0d0
   D_mode=0.0d0
   Mdy=0.0d0

   call update_ext_EM_fields(real_time,check)

#ifdef CPP_OPENMP
!$OMP parallel private(iomp,Beff) default(shared) reduction(+:check1,check2,check3)
#endif
  test_torque=0.0d0
!  dt=get_dt_LLG(timestep_int,damping)/real(N_loop)
  dt=timestep_int/real(N_loop)

  do iomp=1,N_cell

     if (i_excitation) call update_EMT_of_r(iomp,mode_excitation_field(iomp)%w)

     call calculate_Beff(Bini(:,iomp),mode_B_column_1(iomp),B_line_1(iomp),iomp)

!
! Be carefull the sqrt(dt) is not included in BT_mag(iomp),D_T_mag(iomp) at this point. It is included only during the integration
!
     if (i_temperature) call get_temperature_field(mode_temp(iomp)%w(1),damping,mode_magnetic(iomp,1)%w,BT_mag(iomp)%w,D_T_mag(iomp)%w,size(mode_magnetic(iomp,1)%w))

     if (i_magnetic) D_mode_mag(iomp)%w=get_propagator_field(B_mag(iomp)%w,damping,mode_magnetic(iomp,1)%w,size(mode_magnetic(iomp,1)%w))

  enddo

  do iomp=1,N_cell

     all_mode_2(iomp)%w=get_integrator_field(all_mode_1(iomp)%w,D_mode(:,iomp),D_T(:,iomp),dt,mag_lattice%dim_mode)

  enddo

if (N_loop.ge.2) then
  dt=multiply(dt)
  do iomp=1,N_cell

     call calculate_Beff(Bini(:,iomp),mode_B_column_2(iomp),B_line_2(iomp),iomp)

     if (i_magnetic) D_mode_mag(iomp)%w=get_propagator_field(B_mag(iomp)%w,damping,mode_magnetic(iomp,2)%w,size(mode_magnetic(iomp,2)%w))

  enddo

  do iomp=1,N_cell

     all_mode_2(iomp)%w=get_integrator_field(all_mode_1(iomp)%w,D_mode(:,iomp),D_T(:,iomp),dt,mag_lattice%dim_mode)

  enddo
endif

!
!!!!!! Measure the temperature if the users wish
!
do iomp=1,N_cell
   call update_temp_measure(check1,check2,mode_magnetic(iomp,N_loop)%w,B_mag(iomp)%w)
   if (norm_cross(mode_magnetic(iomp,N_loop)%w,B_mag(iomp)%w,1,3).gt.test_torque) test_torque=norm_cross(mode_magnetic(iomp,N_loop)%w,B_mag(iomp)%w,1,3)
enddo
check(1)=check(1)+check1
check(2)=check(2)+check2

#ifdef CPP_OPENMP
!$OMP end parallel
#endif

real_time=real_time+timestep_int
#ifdef CPP_MPI
trans(1)=test_torque
call MPI_REDUCE(trans(1),test_torque,1,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)
#endif

if (j.eq.1) check3=test_torque

call copy_lattice(all_mode_2,all_mode_1)

! calculate energy

#ifdef CPP_OPENMP
!$OMP parallel do private(iomp) default(shared) reduction(+:Edy,Mx,My,Mz,qeuler,vx,vy,vz)
#endif
do iomp=1,N_cell

    call local_energy(Et,iomp,mode_E_column(iomp),E_line(iomp))

    Edy=Edy+Et
    Mdy(1)=Mdy(1)+mode_magnetic(iomp,1)%w(1)
    Mdy(2)=Mdy(2)+mode_magnetic(iomp,1)%w(2)
    Mdy(3)=Mdy(3)+mode_magnetic(iomp,1)%w(3)

    dumy=get_charge(iomp)

    q_plus=q_plus+dumy(1)/pi(4.0d0)
    q_moins=q_moins+dumy(2)/pi(4.0d0)

    vx=vx+dumy(3)
    vy=vy+dumy(4)
    vz=vz+dumy(5)

enddo

#ifdef CPP_OPENMP
!$OMP end parallel do
#endif
vortex=(/vx,vy,vz/)/3.0d0/sqrt(3.0d0)
Edy=Edy/N_cell
Mdy=Mdy/N_cell

!#ifdef CPP_MPI
!      if ((i_Efield).and.(mod(j-1,gra_freq).eq.0).and.(irank.eq.0)) call Efield_sd(j/gra_freq,spin,shape_spin,tableNN,shape_tableNN,masque,indexNN,h_int,mag_lattice,irank,start,isize,MPI_COMM)
!#else
!      if ((i_Efield).and.(mod(j-1,gra_freq).eq.0)) call Efield_sd(j/gra_freq,spin,shape_spin,tableNN,masque,indexNN,h_int,mag_lattice)
!#endif

if (dabs(check(2)).gt.1.0d-8) call get_temp(security,check,kt)

if (mod(j-1,Efreq).eq.0) Write(7,'(I6,18(E20.12E3,2x),E20.12E3)') j,real_time,Edy, &
     &   norm(Mdy),Mdy,norm(vortex),vortex,q_plus+q_moins,q_plus,q_moins, &
     &   kT/k_B,(security(i),i=1,2),H_int

if ((io_simu%io_Energy_Distrib).and.((mod(j-1,gra_freq).eq.0))) then
         call get_Energy_distrib(j/gra_freq,all_mode_1)
      endif

if ((gra_log).and.(mod(j-1,gra_freq).eq.0)) then
         call CreateSpinFile(j/gra_freq,all_mode_1)
         call WriteSpinAndCorrFile(j/gra_freq,all_mode_1,'SpinSTM_')
         write(6,'(a,3x,I10)') 'wrote Spin configuration and povray file number',j/gra_freq
         write(6,'(a,3x,f14.6,3x,a,3x,I10)') 'real time in ps',real_time/1000.0d0,'iteration',j
      endif

if ((io_stochafield).and.(mod(j-1,gra_freq).eq.0)) then
         call WriteSpinAndCorrFile(j/gra_freq,BT,'Stocha-field_')
         write(6,'(a,I10)')'wrote Spin configuration and povray file number',j/gra_freq
      endif

if ((gra_topo).and.(mod(j-1,gra_freq).eq.0)) then
        Call get_charge_map(j/gra_freq)
      endif

!if ((Ffield).and.(mod(j-1,gra_freq).eq.0)) call field_sd(j/gra_freq,spin,shape_spin,indexNN,shape_index,masque,shape_masque,tableNN,shape_tableNN,h_int,mag_lattice)

! security in case of energy increase in SD and check for convergence
if (((damping*(Edy-Eold).gt.1.0d-10).or.(damping*(Edy-Einitial).gt.1.0d-10)).and.(kt.lt.1.0d-10).and.(.not.said_it_once)) then
#ifdef CPP_MPI
    write(6,'(a)') 'WARNING: the total energy or torque is increasing for non zero damping'
    write(6,'(a)') 'this is not allowed by theory'
    write(6,'(a)') 'please reduce the time step'
#else
    write(6,'(a)') 'WARNING: the total energy or torque is increasing for non zero damping'
    write(6,'(a)') 'this is not allowed by theory'
    write(6,'(a)') 'please reduce the time step'
#endif
    said_it_once=.True.
endif

if (mod(j-1,Efreq).eq.0) write(8,'(I10,3x,3(E20.12E3,3x))') j,Edy,test_torque,ave_torque

      check3=test_torque
      Eold=Edy

#ifdef CPP_MPI
      endif
      call mpi_barrier(MPI_COMM,ierr)
#endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! update timestep
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call update_time(timestep_int,Bini,BT,damping)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!! end of a timestep
enddo
!!!!!!!!!!!!!!! end of a timestep
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifdef CPP_MPI
      if (irank.eq.0) then
#endif
      close(7)
      close(8)

#ifdef CPP_MPI
      endif
#endif

if ((dabs(check(2)).gt.1.0d-8).and.(kt/k_B.gt.1.0d-5)) then
    write(6,'(a,2x,f16.6)') 'Final Temp (K)', check(1)/check(2)/2.0d0/k_B
    write(6,'(a,2x,f14.7)') 'Kinetic energy (meV)', (check(1)/check(2)/2.0d0-kT)/k_B*1000.0d0
else
    write(6,'(a)') 'the temperature measurement is not possible'
endif

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  copy the last spin lattice into the mag_lattice
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end subroutine spindynamics
