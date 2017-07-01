      module m_average_MC
      interface CalculateAverages
       module procedure initialize_ave
       module procedure update_ave
      end interface CalculateAverages
      interface Calculate_thermo
       module procedure Calculate_thermo_serial
       module procedure Calculate_thermo_images
      end interface Calculate_thermo
      contains

! ===============================================================
      subroutine Calculate_thermo_images(Cor_log,n_average, &
    &    N_cell,kT,E_sq_sum_av,E_sum_av,M_sq_sum_av, &
    &    C,chi_M,E_av,E_err_av,M_err_av,qeulerp_av,qeulerm_av,vortex_av,Q_sq_sum_av,Qp_sq_sum_av,Qm_sq_sum_av,chi_Q,chi_l, &
    &    M_sum_av,M_av,size_table)
      use m_constants, only : pi
      Implicit none
      logical, intent(in) :: Cor_log
      integer, intent(in) :: n_average,size_table
      real(kind=8), intent(in) :: N_cell,kT(:),E_sq_sum_av(:),E_sum_av(:),M_sq_sum_av(:,:),M_sum_av(:,:),Q_sq_sum_av(:),Qp_sq_sum_av(:),Qm_sq_sum_av(:)
      real(kind=8), intent(out) :: C(:),chi_M(:,:),E_av(:),chi_l(:,:),E_err_av(:),M_err_av(:,:),chi_Q(:,:),M_av(:,:)
      real(kind=8), intent(inout) :: qeulerp_av(:),qeulerm_av(:),vortex_av(:,:)
! internal variables
      real(kind=8) :: Total_MC_Steps
      integer :: i

       chi_l=0.0d0
       E_err_av=0.0d0
       M_err_av=0.0d0
       Total_MC_Steps=dble(n_average)
       chi_Q=0.0d0

       do i=1,size_table
         C(i)=(E_sq_sum_av(i)/Total_MC_Steps-(E_sum_av(i)/(Total_MC_Steps))**2)/kT(i)**2/N_cell
         chi_M(:,i)=(M_sq_sum_av(:,i)/Total_MC_Steps-(M_sum_av(:,i)/Total_MC_Steps)**2)/kT(i)/N_cell
         if (n_average.gt.1) E_err_av(i)=sqrt(abs(E_sq_sum_av(i)-(E_sum_av(i))**2/Total_MC_Steps)/(Total_MC_Steps-1))/N_cell
         if (n_average.gt.1) M_err_av(:,i)=sqrt(abs(M_sq_sum_av(:,i)-M_sum_av(:,i)**2/Total_MC_Steps)/(Total_MC_Steps-1))/N_cell
         E_av(i)=E_sum_av(i)/Total_MC_Steps/N_cell
         M_av(:,i)=M_sum_av(:,i)/Total_MC_Steps/N_cell
         qeulerp_av(i)=qeulerp_av(i)/Total_MC_Steps/pi(4.0d0)
         qeulerm_av(i)=qeulerm_av(i)/Total_MC_Steps/pi(4.0d0)
         chi_Q(1,i)=(Q_sq_sum_av(i)/Total_MC_Steps/pi(4.0d0)**2-(qeulerp_av(i)+qeulerm_av(i))**2)/kT(i)
         chi_Q(2,i)=(Qp_sq_sum_av(i)/Total_MC_Steps/pi(4.0d0)**2-qeulerp_av(i)**2)/kT(i)
         chi_Q(3,i)=(Qm_sq_sum_av(i)/Total_MC_Steps/pi(4.0d0)**2-qeulerm_av(i)**2)/kT(i)
         chi_Q(4,i)=((-Qm_sq_sum_av(i)/Total_MC_Steps/pi(4.0d0)**2-qeulerm_av(i)**2)* &
     &    (Qp_sq_sum_av(i)/Total_MC_Steps/pi(4.0d0)**2-qeulerp_av(i)**2))/kT(i)
         vortex_av(:,i)=vortex_av(:,i)/Total_MC_Steps/3.0d0/sqrt(3.0d0)
         if (Cor_log) chi_l(:,i)=total_MC_steps
       enddo

      END subroutine Calculate_thermo_images

! ===============================================================
      subroutine Calculate_thermo_serial(Cor_log,n_average, &
    &    N_cell,kT,E_sq_sum_av,E_sum_av,M_sq_sum_av, &
    &    C,chi_M,E_av,E_err_av,M_err_av,qeulerp_av,qeulerm_av,vortex_av,Q_sq_sum,Qp_sq_sum,Qm_sq_sum, &
    &    chi_Q,chi_l, &
    &    M_sum_av,M_av)
      use m_constants, only : pi
      Implicit none
      logical, intent(in) :: Cor_log
      integer, intent(in) :: n_average
      real(kind=8), intent(in) :: N_cell,kT,E_sq_sum_av,E_sum_av,M_sq_sum_av(:),M_sum_av(:),Q_sq_sum,Qp_sq_sum,Qm_sq_sum
      real(kind=8), intent(out) :: C,chi_M(:),E_av,chi_l(:),E_err_av,M_err_av(:),chi_Q(:),M_av(:)
      real(kind=8), intent(inout) :: qeulerp_av,qeulerm_av,vortex_av(:)
! internal variables
      real(kind=8) :: Total_MC_Steps
! components of teh spins

       chi_l=0.0d0
       E_err_av=0.0d0
       M_err_av=0.0d0
       Total_MC_Steps=dble(n_average)
       chi_Q=0.0d0

!      If compiled serial!
       C=(E_sq_sum_av/Total_MC_Steps-(E_sum_av/(Total_MC_Steps))**2)/kT**2/N_cell
       chi_M=(M_sq_sum_av(:)/Total_MC_Steps-(M_sum_av(:)/Total_MC_Steps)**2)/kT/N_cell
       if (n_average.gt.1) E_err_av=sqrt(abs(E_sq_sum_av-(E_sum_av)**2/Total_MC_Steps)/(Total_MC_Steps-1))/N_cell
       if (n_average.gt.1) M_err_av(:)=sqrt(abs(M_sq_sum_av(:)-M_sum_av(:)**2/Total_MC_Steps)/(Total_MC_Steps-1))/N_cell
       E_av=E_sum_av/Total_MC_Steps/N_cell
       M_av=M_sum_av(:)/Total_MC_Steps/N_cell
       qeulerp_av=qeulerp_av/Total_MC_Steps/pi(4.0d0)
       qeulerm_av=qeulerm_av/Total_MC_Steps/pi(4.0d0)
       chi_Q(1)=((qeulerp_av+qeulerm_av)**2-Q_sq_sum/Total_MC_Steps/pi(4.0d0)**2)/kT
       chi_Q(2)=(qeulerp_av**2-Qp_sq_sum/Total_MC_Steps/pi(4.0d0)**2)/kT
       chi_Q(3)=(qeulerm_av**2-Qm_sq_sum/Total_MC_Steps/pi(4.0d0)**2)/kT
       chi_Q(4)=((-Qm_sq_sum/Total_MC_Steps/pi(4.0d0)**2-qeulerm_av**2)* &
     &   (Qm_sq_sum/Total_MC_Steps/pi(4.0d0)**2-qeulerp_av**2))/kT
       vortex_av(:)=vortex_av(:)/Total_MC_Steps/3.0d0/sqrt(3.0d0)
       if (Cor_log) chi_l(:)=total_MC_steps

      END subroutine Calculate_thermo_serial

! ===============================================================
      subroutine update_ave(sum_qp,sum_qm,Q_sq_sum,Qp_sq_sum,Qm_sq_sum,sum_vortex,vortex, &
     & E_sum,E_sq_sum,M_sum,M_sq_sum,E,Magnetization,spin_sum,spin,shape_spin,masque,shape_masque)
      use m_topocharge_all
      Implicit none
      integer, intent(in) :: shape_spin(:),masque(:,:,:,:),shape_masque(:)
      real(kind=8), intent(in) :: E,Magnetization(:),vortex(:)
      real(kind=8), intent(in) :: spin(:,:,:,:,:)
      real(kind=8), intent(inout) ::sum_qm,sum_qp,sum_vortex(:),Q_sq_sum,Qp_sq_sum,Qm_sq_sum
      real(kind=8), intent(inout) :: E_sum,E_sq_sum,M_sum(:),M_sq_sum(:)
      real(kind=8), intent(inout) :: spin_sum(:,:,:,:,:)
! internal variables
      real(kind=8) :: qeulerp,qeulerm
! components of teh spins
      integer :: X,Y,Z,M

      X=shape_spin(1)-3
      Y=shape_spin(1)-2
      Z=shape_spin(1)-1
      M=shape_spin(1)

      qeulerp=0.0d0
      qeulerm=0.0d0
!     estimating the values M_av, E_av, S and C
!     and do so for any sublattice

      E_sum=E_sum+E
      E_sq_sum=E_sq_sum+E**2

! calculate the topocharge
      call topo(spin,shape_spin,masque,shape_masque,qeulerp,qeulerm)

      sum_qp=sum_qp+qeulerp
      sum_qm=sum_qm+qeulerm
      Q_sq_sum=Q_sq_sum+(qeulerp+qeulerm)**2
      Qp_sq_sum=Qp_sq_sum+qeulerp**2
      Qm_sq_sum=Qm_sq_sum+qeulerm**2
      M_sum=M_sum+Magnetization
      M_sq_sum=M_sq_sum+Magnetization**2
      sum_vortex=sum_vortex+vortex

! calculate the average of the spins for the fft
      spin_sum=spin_sum+spin(X:M,:,:,:,:)

      END subroutine update_ave

! ===============================================================
      subroutine initialize_ave(spin,shape_spin,masque,shape_masque,qeulerp,qeulerm,vortex,Magnetization,n_system)
      use m_topocharge_local, only : local_topo,local_vortex
#ifdef CPP_MPI
      use m_make_box, only : Xstart,Xstop,Ystart,Ystop,Zstart,Zstop
#endif
      Implicit none
      integer, intent(in) :: shape_spin(5),shape_masque(4),n_system
      real(kind=8), intent(in) :: spin(shape_spin(1),shape_spin(2),shape_spin(3),shape_spin(4),shape_spin(5))
      integer, intent(in) :: masque(shape_masque(1),shape_masque(2),shape_masque(3),shape_masque(4))
      real(kind=8), intent(out) :: vortex(3),qeulerp,qeulerm,Magnetization(3)
! dumy
      integer :: i_x,i_y,i_z,i_m
      real(kind=8) :: qp,qm,v(3)
#ifndef CPP_MPI
      integer :: Xstart,Xstop,Ystart,Ystop,Zstart,Zstop

      Xstart=1
      Xstop=shape_spin(2)
      Ystart=1
      Ystop=shape_spin(3)
      Zstart=1
      Zstop=shape_spin(4)
#endif

      v=0.0d0
      qp=0.0d0
      qm=0.0d0
      qeulerp=0.0d0
      qeulerm=0.0d0
      vortex=0.0d0
      Magnetization=0.0d0

#ifdef CPP_OPENMP
!$OMP parallel DO REDUCTION(+:Magnetization) private(i_x,i_y,i_z,i_m) default(shared)
#endif

      do i_m=1,shape_spin(5)
       do i_z=Zstart,Zstop
        do i_y=Ystart,Ystop
         do i_x=Xstart,Xstop
          Magnetization=Magnetization+Spin(4:6,i_x,i_y,i_z,i_m)
         enddo
        enddo
       enddo
      enddo

#ifdef CPP_OPENMP
!$OMP end parallel do
#endif

! calculate the topological charge and the vortivity for the different types of system.

      do i_m=1,shape_spin(5)
#ifdef CPP_OPENMP
!$OMP parallel DO REDUCTION(+:qeulerp,qeulerm,v) private(i_x,i_y,i_z) default(shared)
#endif

       do i_z=Zstart,Zstop
        do i_y=Ystart,Ystop
         do i_x=Xstart,Xstop

         select case(n_system)
          case(2)
           call local_topo(i_x,i_y,qm,qp,spin,shape_spin,masque,shape_masque)
           call local_vortex(i_x,i_y,v,spin,shape_spin,masque,shape_masque)
          case(22)
           call local_topo(i_x,i_y,i_m,qm,qp,spin,shape_spin,masque,shape_masque)
          case(32)
           call local_topo(i_x,i_y,i_z,i_m,qm,qp,spin,shape_spin,masque,shape_masque)
          case default
           call local_topo(i_x,i_y,qm,qp,spin,shape_spin,masque,shape_masque)
          end select
         qeulerp=qeulerp+qp
         qeulerm=qeulerm+qm
         vortex=vortex+v

         enddo
        enddo
       enddo
#ifdef CPP_OPENMP
!$OMP end parallel do
#endif
      enddo

! end

      qeulerp=qeulerp
      qeulerm=qeulerm

      END subroutine initialize_ave

      end module m_average_MC
! ===============================================================
