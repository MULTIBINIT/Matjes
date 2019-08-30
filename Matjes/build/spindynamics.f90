subroutine spindynamics(mag_lattice,mag_motif,io_simu,gra_topo,ext_param)
use m_fieldeff
use m_info_dynamics
use m_torques, only : get_torques
use m_eval_BTeff
use m_measure_temp
use m_topo_commons, only : get_size_Q_operator,associate_Q_operator
use m_derived_types
use m_update_time
use m_solver
use m_dynamic
use m_vector, only : cross,norm,norm_cross
use m_sd_averages
use m_randist
use m_constants, only : pi,k_b,hbar
use m_topo_sd
use m_eval_Beff
use m_write_spin
use m_energyfield, only : get_Energy_distrib,get_Energy_distrib_line
use m_createspinfile
use m_energy
use m_local_energy
use m_dyna_utils
use m_energy_commons, only : get_E_line
use m_internal_fields_commons, only : get_B_line
use m_user_info
use m_excitations
#ifndef CPP_BRUTDIP
      use m_setup_dipole, only : mmatrix
#endif
#ifdef CPP_MPI
      use m_parameters, only : i_ghost
      use m_mpi_prop, only : MPI_COMM,irank,isize,start
      use m_reconstruct_mat
#endif
      implicit none
! input
type(lattice), intent(inout) :: mag_lattice
type(cell), intent(in) :: mag_motif
type(io_parameter), intent(in) :: io_simu
type(simulation_parameters), intent(in) :: ext_param
logical, intent(in) :: gra_topo
! internal
logical :: gra_log,io_stochafield
integer :: i,j,l,k,h,gra_freq
! lattices that are used during the calculations
real(kind=8),allocatable,dimension(:,:,:,:,:) :: spinafter,Bini,BT
type(vec_point),allocatable,dimension(:) :: spin1,spin2,B_point,B_after_point,BT_point
! lattice pf pointer that will be used in the simulation
type(point_shell_Operator), allocatable, dimension(:) :: E_line,B_line_1,B_line_2
type(point_shell_mode), allocatable, dimension(:) :: mode_E_column,mode_B_column_1,mode_B_column_2
! dummys
real(kind=8) :: dum_norm,qeuler,q_plus,q_moins,vortex(3),Mdy(3),Edy,stmtorquebp,check1,check2,Eold,check3,Et
real(kind=8) :: Mx,My,Mz,vx,vy,vz,check(2),test_torque,Einitial,ave_torque
real(kind=8) :: dumy(5),ds(3),security(2),B(3),step(3),steptor(3),stepadia(3),stepsttor(3),steptemp(3)
real(kind=8) :: timestep_int,real_time,h_int(3)
real(kind=8) :: kt,ktini,ktfin,kt1
real(kind=8) :: time
integer :: iomp,shape_lattice(4),shape_spin(4),N_cell
! parameter for the Heun integration scheme
real(kind=8) :: maxh
! parameter for the rkky integration
integer :: N_site_comm
! dumy
      logical :: said_it_once,i_anatorque
! starting and ending points of the sums
      integer :: Mstop
#ifndef CPP_MPI
      integer, dimension(3), parameter :: start=0
#endif
      integer :: Xstart,Xstop,Ystart,Ystop,Zstart,Zstop
#ifdef CPP_MPI
      real(kind=8) :: mpi_check(2),trans(3)

      include 'mpif.h'

      trans=0.0d0
#endif
! VERY IMPORTANT PART THAT DEFINES THE BOUNDARIES OF THE SUM
! starting point and ending points in the sums
      shape_lattice=shape(mag_lattice%l_modes)
      Xstart=start(1)+1
      Xstop=start(1)+shape_lattice(1)
      Ystart=start(2)+1
      Ystop=start(2)+shape_lattice(2)
      Zstart=start(3)+1
      Zstop=start(3)+shape_lattice(3)
      Mstop=shape_lattice(4)
      N_cell=product(shape_lattice(1:3))

      N_site_comm=(Xstop-Xstart+1)*(Ystop-Ystart+1)*(Zstop-Zstart+1)*shape_lattice(4)
      i_anatorque=.False.

#ifdef CPP_MPI
      if (irank.eq.0) then
#endif
      OPEN(7,FILE='EM.dat',action='write',status='replace',form='formatted')
      Write(7,'(20(a,2x))') '# 1:step','2:real_time','3:E_av','4:M', &
     &  '5:Mx','6:My','7:Mz','8:vorticity','9:vx', &
     &  '10:vy','11:vz','12:qeuler','13:q+','14:q-','15:T=', &
     &  '16:Tfin=','17:Ek=','18:Hx','19:Hy=','20:Hz='

! check the convergence
      open(8,FILE='convergence.dat',action='write',form='formatted')
#ifdef CPP_MPI
      endif
#endif

! prepare the matrices for integration

call rw_dyna(shape_lattice(1:3),mag_lattice)

allocate(spin1(N_cell),spin2(N_cell),B_point(N_cell),BT_point(N_cell))
allocate(spinafter(mag_lattice%dim_mode,shape_lattice(1),shape_lattice(2),shape_lattice(3),shape_lattice(4)))
allocate(Bini(mag_lattice%dim_mode,shape_lattice(1),shape_lattice(2),shape_lattice(3),shape_lattice(4)))
allocate(BT(mag_lattice%dim_mode,shape_lattice(1),shape_lattice(2),shape_lattice(3),shape_lattice(4)))

shape_spin=shape_lattice
Bini=0.0d0
spinafter=0.0d0
BT=0.0d0

call associate_pointer(spin1,mag_lattice)
call associate_pointer(spin2,spinafter)
call associate_pointer(B_point,Bini)
call associate_pointer(BT_point,BT)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! allocate the pointers for the B-field and the energy
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!!!! test

time=0.0d0
call user_info(6,time,'associate H_line, B_line and S_line',.true.)

allocate(E_line(N_cell),B_line_1(N_cell),B_line_2(N_cell))
allocate(mode_E_column(N_cell),mode_B_column_1(N_cell),mode_B_column_2(N_cell))

call get_E_line(E_line,mode_E_column,spin1)

call get_B_line(B_line_1,mode_B_column_1,spin1)
call get_B_line(B_line_2,mode_B_column_2,spin2)

if (io_simu%io_Energy_Distrib) then
   write(6,'(a)') 'setting up energy distribution'
   call get_Energy_distrib_line(spin1)
endif

call user_info(6,time,'done - ready to start calculations',.true.)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! associate pointer for the topological charge, vorticity calculations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call user_info(6,time,'topological operators',.false.)

call get_size_Q_operator(mag_lattice)

call associate_Q_operator(spin1,mag_lattice%boundary,shape_spin)

call user_info(6,time,'done',.true.)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! start the simulation
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

timestep_int=timestep
gra_log=io_simu%io_Xstruct
io_stochafield=io_simu%io_Tfield
gra_freq=io_simu%io_frequency
ktini=ext_param%ktini%value
ktfin=ext_param%ktfin%value
kt=ktini

      iomp=1
!      if (maxh.lt.1.0d-8)
      maxh=1.0d0
      Eold=100.0d0
      k=0
      h=0
      l=0
      kt=ktini
      step=0.0d0
      steptor=0.0d0
      stepadia=0.0d0
      stepsttor=0.0d0
      steptemp=0.0d0
      real_time=0.0d0
      Einitial=0.0d0
      h_int=ext_param%H_ext%value
      said_it_once=.False.

      stmtorquebp=storque
      security=0.0d0

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! part of the excitations
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call get_excitations('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! do we use the update timestep
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call init_update_time('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! initialize the difference torques
!!!!!!!!!!!!!!!!!!!!!!!!!!!!
call get_torques('input')

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! beginning of the
do j=1,duration
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifndef CPP_BRUTDIP
      if (i_dip) then
#ifdef CPP_OPENMP
!$OMP parallel private(i_x,i_y,i_z) default(shared)
#endif
       do i_z=1,shape_spin(4)
        do i_y=1,shape_spin(3)
         do i_x=1,shape_spin(2)
        mmatrix(:,i_x,i_y,i_z)=spin(1:3,i_x,i_y,i_z,1)
         enddo
        enddo
       enddo
#ifdef CPP_OPENMP
!$OMP end parallel
#endif
      endif
#endif
! send the lattice to the processors
!------------------------------
!        call dyna_split(i_dip,MPI_WORKING_WORLD,irank)
!       call MPI_BCAST(Spin(4:7,:,:,:,:),product(dim_lat)*count(motif%i_m)*4,MPI_REAL8,0, &
!     &     MPI_WORKING_WORLD,ierr)
!       write(*,*) '-----------------------'
!       write(*,*) j
!       write(*,*) '-----------------------'

       call init_temp_measure(check,check1,check2,check3)
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

       do iomp=1,N_cell
          BT_point(iomp)%w=0.0d0
       enddo


!       if (((j.lt.ti).or.(j.gt.tf)).and.(marche)) then
!        storque=0.0d0
!        elseif (((j.gt.ti).and.(j.lt.tf)).and.(marche)) then
!        storque=stmtorquebp
!       endif

!       kT=(118.0d0/(1+(real(j)*timestep_int-10.0d0)**2/2.9d0)+250.0d0)/650.0d0*60.0d0
!       if (j.lt.1538) then
!          kt1=250.0d0+300.0d0*exp(-(real(j)*timestep_int/1000.0d0-1.5)**2/0.5)
!       else
!          kt1=100.0d0+400.0d0/log(real(j)*timestep_int/1000.0d0+0.9)
!       endif
!
!       kt=kt1/650.0d0*28.0d0*k_b

       call update_EM_fields(real_time,kt,h_int,check)


       if ((h.gt.htimes).and.(hsweep).and.(norm((H_int-Hfin)).gt.1.0d-6).and. &
          (j.gt.hstart)) then
        H_int=H_int+hstep
        h=1
#ifdef CPP_MPI
        if (irank.eq.0) write(6,'(a,2x,3f8.4)') 'applied field', (H_int(i),i=1,3)
#else
        write(6,'(a,2x,3f8.4)') 'applied field', (H_int(i),i=1,3)
#endif
       endif


!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     FIRST LOOP
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#ifdef CPP_OPENMP
!$OMP parallel private(iomp,Beff) default(shared) reduction(+:check1,check2,check3)
#endif
test_torque=0.0d0

do iomp=1,N_cell

! different integration types
!-----------------------------------------------
! Euler integration scheme
!-----------------------------------------------
      select case (integtype)
       case (1)

       call calculate_Beff(iomp,B_point(iomp)%w,mode_B_column_1(iomp),h_int,B_line_1(iomp))

       if (kt.gt.1.0d-10) call calculate_BTeff(stmtemp,kt,BT_point(iomp)%w)

!
!-----------------------------------------------
! Heun integration scheme
!-----------------------------------------------
       case (3)

       call calculate_Beff(iomp,B_point(iomp)%w,mode_B_column_1(iomp),h_int,B_line_1(iomp))

       if (kt.gt.1.0d-10) call calculate_BTeff(stmtemp,kt,BT_point(iomp)%w)

!
!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (2)
!       call calculate_Beff(iomp,Beff,spin1,h_int,Hamiltonian)
!
!        spin2(iomp)%w=(integrate(timestep_int,spin1(:,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     & ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,Ipol,i_x,i_y,i_z,i_m,spin)+ &
!     & spinini(:,i_x,i_y,i_z,i_m))/2.0d0

!
!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (4)
!       call calculate_Beff(i_x,i_y,i_z,i_m,Beff,spin,shape_spin,mag_lattice,h_int,Hamiltonian)

!        spinafter(:,i_x,i_y,i_z,i_m)=(integrate(timestep_int,spin(4:6,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     & ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,check,Ipol,i_x,i_y,i_z,i_m,spin)+ &
!     &  spinini(:,i_x,i_y,i_z,i_m))/2.0d0

!
!-----------------------------------------------
! SIB without temperature and with error control
!-----------------------------------------------
       case (6)
        call calculate_Beff(iomp,B_point(iomp)%w,mode_B_column_1(iomp),h_int,B_line_1(iomp))

!
!-----------------------------------------------
! other cases
!-----------------------------------------------
      case default

        stop 'not implemented'

      end select

enddo


do iomp=1,N_cell

! different integration types
!-----------------------------------------------
! Euler integration scheme
!-----------------------------------------------
      select case (integtype)
       case (1)

        spin2(iomp)%w=simple(timestep_int,B_point(iomp)%w(1:3),BT_point(iomp)%w(1:3),damping,spin1(iomp)%w(1:3))

! the temperature is checked with 1 temperature step before
!!! check temperature
        call update_temp_measure(check1,check2,spin2(iomp)%w,B_point(iomp)%w)
        if (norm_cross(spin2(iomp)%w,B_point(iomp)%w,1,mag_lattice%dim_mode).gt.test_torque) test_torque=norm_cross(spin2(iomp)%w,B_point(iomp)%w,1,mag_lattice%dim_mode)

!!! end check

!-----------------------------------------------
! Heun integration scheme
!-----------------------------------------------
       case (3)

        spin2(iomp)%w=simple(timestep_int,B_point(iomp)%w(1:3),BT_point(iomp)%w(1:3),damping,spin1(iomp)%w(1:3))


!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (2)
!        call calculate_Beff(i_x,i_y,i_z,i_m,Beff,spin,shape_spin,mag_lattice,h_int,Hamiltonian)
!
!        spinafter(:,i_x,i_y,i_z,i_m)=integrate(timestep_int,spinini(1:3,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     &   ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,check,Ipol,i_x,i_y,i_z,i_m,spin)
!
!
!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (4)
!        call calculate_Beff(i_x,i_y,i_z,i_m,Beff,spin,shape_spin,mag_lattice,h_int,Hamiltonian)
!
!        spinafter(:,i_x,i_y,i_z,i_m)=integrate(timestep_int,spinini(1:3,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     & ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,check,Ipol,i_x,i_y,i_z,i_m,spin)
!
!-----------------------------------------------
! SIB without temperature
!-----------------------------------------------
       case (6)

        spin2(iomp)%w=(integrate_SIB_NC_ohneT(timestep_int,B_point(iomp)%w,BT_point(iomp)%w,damping,spin1(iomp)%w)+spin1(iomp)%w)/2.0d0

       case default
        stop 'not implemented'
       end select

enddo

!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
!     SECOND LOOP
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!

do iomp=1,N_cell


! different integration types
!-----------------------------------------------
! Euler integration scheme
!-----------------------------------------------
     select case (integtype)
      case (1)

      exit

!-----------------------------------------------
! Heun integration scheme
!-----------------------------------------------
      case (3)

       call calculate_Beff(iomp,B,mode_B_column_2(iomp),h_int,B_line_2(iomp))

       B_point(iomp)%w=(B+B_point(iomp)%w)/2.0d0

!-----------------------------------------------
! SIB without temperature
!-----------------------------------------------
       case (6)

        call calculate_Beff(iomp,B,mode_B_column_2(iomp),h_int,B_line_2(iomp))

      case default
        stop 'not implemented'
     end select

enddo


do iomp=1,N_cell

! different integration types
!-----------------------------------------------
! Euler integration scheme
!-----------------------------------------------
     select case (integtype)
      case (1)

      exit

!-----------------------------------------------
! Heun integration scheme
!-----------------------------------------------
       case (3)

         spin2(iomp)%w=simple(timestep_int,B_point(iomp)%w(1:3),BT_point(iomp)%w(1:3),damping,spin1(iomp)%w(1:3))

!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (2)
!        call calculate_Beff(i_x,i_y,i_z,i_m,Beff,spin,shape_spin,mag_lattice,h_int,Hamiltonian)
!
!        spinafter(:,i_x,i_y,i_z,i_m)=integrate(timestep_int,spinini(1:3,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     &   ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,check,Ipol,i_x,i_y,i_z,i_m,spin)
!
!
!-----------------------------------------------
! SIA and IMP integration scheme
!-----------------------------------------------
!       case (4)
!        call calculate_Beff(i_x,i_y,i_z,i_m,Beff,spin,shape_spin,mag_lattice,h_int,Hamiltonian)
!
!        spinafter(:,i_x,i_y,i_z,i_m)=integrate(timestep_int,spinini(1:3,i_x,i_y,i_z,i_m),Beff,kt,damping &
!     & ,stmtemp,i_torque,stmtorque,torque_FL,torque_AFL,adia,nonadia,storque,maxh,check,Ipol,i_x,i_y,i_z,i_m,spin)
!
!-----------------------------------------------
! SIB without temperature
!-----------------------------------------------
       case (6)

        spin2(iomp)%w=integrate_SIB_NC_ohneT(timestep_int,B_point(iomp)%w,BT_point(iomp)%w,damping,spin1(iomp)%w)

       case default
        stop 'not implemented'
       end select


! the temperature is checked with 1 temperature step before
!!! check temperature
    call update_temp_measure(check1,check2,spin2(iomp)%w,B_point(iomp)%w)
    if (norm_cross(spin2(iomp)%w,B_point(iomp)%w,1,mag_lattice%dim_mode).gt.test_torque) test_torque=norm_cross(spin2(iomp)%w,B_point(iomp)%w,1,mag_lattice%dim_mode)
!!! end check

enddo


#ifdef CPP_OPENMP
!$OMP end parallel
#endif
check(1)=check(1)+check1
check(2)=check(2)+check2
real_time=real_time+timestep_int
#ifdef CPP_MPI
trans(1)=test_torque
call MPI_REDUCE(trans(1),test_torque,1,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)
#endif

if (j.eq.1) check3=test_torque

#ifdef CPP_MPI
! gather to take into account the possible change of size of spinafter
!------------------------------
!if (i_ghost) then
!   call rebuild_mat(spinafter,N_site_comm*4,spin)
!else
!   call copy_lattice(spin,spinafter)
!endif
#else
call copy_lattice(spin2,spin1)
#endif

! calculate energy

#ifdef CPP_OPENMP
!$OMP parallel do private(iomp) default(shared) reduction(+:Edy,Mx,My,Mz,qeuler,vx,vy,vz)
#endif
do iomp=1,N_cell

    call local_energy_pointer(Et,iomp,mode_E_column(iomp),E_line(iomp))

    Edy=Edy+Et
    Mx=Mx+Spin1(iomp)%w(1)
    My=My+Spin1(iomp)%w(2)
    Mz=Mz+Spin1(iomp)%w(3)

    dumy=sd_charge(iomp)

    q_plus=q_plus+dumy(1)/pi(4.0d0)
    q_moins=q_moins+dumy(2)/pi(4.0d0)

    vx=vx+dumy(3)
    vy=vy+dumy(4)
    vz=vz+dumy(5)

enddo

#ifdef CPP_OPENMP
!$OMP end parallel do
#endif
      Mdy=(/Mx,My,Mz/)
      vortex=(/vx,vy,vz/)/3.0d0/dsqrt(3.0d0)

#ifdef CPP_MPI
       trans(1)=Edy
       call MPI_ALLREDUCE(trans(1),Edy,1,MPI_REAL8,MPI_SUM,MPI_COMM,ierr)
       trans(1:3)=Mdy
       call MPI_REDUCE(trans(1:3),Mdy,3,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)
       trans(1)=qeuler
       call MPI_REDUCE(trans(1),qeuler,1,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)
       trans(1:3)=vortex
       call MPI_REDUCE(trans(1:3),vortex,3,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)
       trans(1:2)=check
       call MPI_REDUCE(trans(1:2),check,2,MPI_REAL8,MPI_SUM,0,MPI_COMM,ierr)

      if (j.eq.1) Einitial=Edy/N_cell
#endif
!#ifdef CPP_MPI
!      if ((i_Efield).and.(mod(j-1,gra_freq).eq.0).and.(irank.eq.0)) call Efield_sd(j/gra_freq,spin,shape_spin,tableNN,shape_tableNN,masque,indexNN,h_int,mag_lattice,irank,start,isize,MPI_COMM)
!#else
!      if ((i_Efield).and.(mod(j-1,gra_freq).eq.0)) call Efield_sd(j/gra_freq,spin,shape_spin,tableNN,masque,indexNN,h_int,mag_lattice)
!#endif

#ifdef CPP_MPI
       if (irank.eq.0) then
#endif
      Edy=Edy/N_cell
      Mdy=Mdy/N_cell

if (dabs(check(2)).gt.1.0d-8) call get_temp(security,check,kt)

if (mod(j-1,Efreq).eq.0) Write(7,'(I6,18(E20.12E3,2x),E20.12E3)') j,real_time,Edy, &
     &   norm(Mdy),Mdy,norm(vortex),vortex,q_plus+q_moins,q_plus,q_moins, &
     &   kT/k_B,(security(i),i=1,2),H_int

if ((io_simu%io_Energy_Distrib).and.((mod(j-1,gra_freq).eq.0))) then
         call get_Energy_distrib(j/gra_freq,spin1,h_int)
      endif

if ((gra_log).and.(mod(j-1,gra_freq).eq.0)) then
         call CreateSpinFile(j/gra_freq,spin1)
         call WriteSpinAndCorrFile(j/gra_freq,spin1,'SpinSTM_')
         write(6,'(a,3x,I10)') 'wrote Spin configuration and povray file number',j/gra_freq
         write(6,'(a,3x,f14.6,3x,a,3x,I10)') 'real time in ps',real_time/1000.0d0,'iteration',j
      endif

if ((io_stochafield).and.(mod(j-1,gra_freq).eq.0)) then
         call WriteSpinAndCorrFile(j/gra_freq,BT_point,'Stocha-field_')
         write(6,'(a,I10)')'wrote Spin configuration and povray file number',j/gra_freq
      endif

if ((gra_topo).and.(mod(j-1,gra_freq).eq.0)) then
   if (size(mag_lattice%world).eq.2) then
        Call topocharge_sd(j/gra_freq,spinafter(:,:,:,1,:),mag_lattice)
       endif
      endif

!if ((io_simu%io_Energy_Distrib).and.(mod(j-1,gra_freq).eq.0)) call get_Energy_distrib(j/gra_freq,spin1)

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
call update_time(timestep_int,B_point,BT_point,damping)

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
