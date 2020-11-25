module m_init_spiral
use m_derived_types
implicit none

private
interface init_spiral
   module procedure init_spiral_old
   module procedure init_spiral_new
end interface
public :: init_spiral

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Initialize the starting configuration as a spin spiral
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


subroutine init_spiral_new(io,fname,lat,ordname,dim_mode,state)
    use m_io_utils, only: get_parameter
    use m_init_util, only: get_pos_vec
    integer,intent(in)              :: io       !init-file io-unit
    character(*),intent(in)         :: fname    !init-file name 
    type(lattice), intent(in)       :: lat      !entire lattice containing geometric information
    character(*),intent(in)         :: ordname  !name of the order parameter
    integer,intent(in)              :: dim_mode !dimension of the order parameter in each cell
    real(8),pointer,intent(inout)   :: state(:) !pointer the the order parameter

    real(8)         :: qvec(3),Rq(3),Iq(3)
    real(8),allocatable,target :: pos(:)
!    real(8),allocatable ::  position(:)
    real(8),pointer :: pos_3(:,:),state_3(:,:)
    integer         :: i
    integer         :: nmag
   
    qvec=0.0d0
    Rq=[0.0d0,0.0d0,1.0d0]
    Iq=[1.0d0,0.0d0,0.0d0]
    
    call get_parameter(io,fname,'qvec_'//ordname,3,qvec)
    qvec=matmul(qvec,lat%astar)

    call get_parameter(io,fname,'Rq_'//ordname,3,Rq,1.0d0)
    Rq=matmul(Rq,lat%areal)
    Rq=Rq/norm2(Rq)
    
    call get_parameter(io,fname,'Iq_'//ordname,3,Iq,1.0d0)
    Iq=matmul(Iq,lat%areal)
    Iq=Iq/norm2(Iq)

    Call get_pos_vec(lat,dim_mode,ordname,pos)

    pos_3(1:3,1:size(pos)/3)=>pos
    state_3(1:3,1:size(pos)/3)=>state
    do i=1,size(state_3,2)
        state_3(:,i)=(cos(dot_product(qvec,pos_3(:,i)))*Rq+ &
                      sin(dot_product(qvec,pos_3(:,i)))*Iq)
    enddo
    nullify(pos_3,state_3)
    deallocate(pos)
end subroutine 


subroutine init_spiral_old(io,fname,my_lattice,my_motif,mode_name,start,end)
use m_get_position
use m_vector
use m_io_utils
use m_convert
type (lattice), intent(inout) :: my_lattice
type(t_cell), intent(in) :: my_motif
integer, intent(in) :: io,start,end
character(len=*), intent(in) :: fname,mode_name
! internal variables
real(kind=8) :: qvec(3),Rq(3),Iq(3),dumy_vec(3),kvec(3,3),r(3,3),ss
integer :: i_z,i_y,i_x,i_m,Nx,Ny,Nz,Nmag,size_mag
real(kind=8), allocatable :: position(:,:,:,:,:)
character(len=30) :: variable_name

!!new internal variables
!real(8), allocatable,target :: pos_new(:,:,:,:,:)
!real(8),pointer :: pos_new_flat(:,:),mag_point(:,:)
!integer         :: i

kvec=my_lattice%astar
r=my_lattice%areal
qvec=0.0d0
Rq=[0.0d0,0.0d0,1.0d0]
Iq=[1.0d0,0.0d0,0.0d0]

variable_name=convert('qvec_',mode_name)
call get_parameter(io,fname,variable_name,3,qvec)
dumy_vec=qvec(1)*kvec(1,:)+qvec(2)*kvec(2,:)+qvec(3)*kvec(3,:)
qvec=dumy_vec

variable_name=convert('Rq_',mode_name)
call get_parameter(io,fname,variable_name,3,Rq,1.0d0)
dumy_vec=Rq(1)*r(1,:)+Rq(2)*r(2,:)+Rq(3)*r(3,:)
ss=norm(dumy_vec)
Rq=dumy_vec/ss

variable_name=convert('Iq_',mode_name)
call get_parameter(io,fname,variable_name,3,Iq,1.0d0)
dumy_vec=Iq(1)*r(1,:)+Iq(2)*r(2,:)+Iq(3)*r(3,:)
ss=norm(dumy_vec)
Iq=dumy_vec/ss

! get the position of the sites on the lattice
Nx=my_lattice%dim_lat(1)
Ny=my_lattice%dim_lat(2)
Nz=my_lattice%dim_lat(3)
nmag=count(my_motif%atomic(:)%moment.gt.0.0d0)
size_mag=size(my_motif%atomic(:))

allocate(position(3,Nx,Ny,Nz,Nmag))
call get_position(position,my_lattice%dim_lat,my_lattice%areal,my_motif)

do i_m=1,nmag
!   if (my_motif%atomic(i_m)%moment.lt.1.0d-8) cycle
   do i_z=1,Nz
      do i_y=1,Ny
         do i_x=1,Nx
!normal spin spiral
            my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(start:end)=( cos( dot_product(qvec,position(:,i_x,i_y,i_z,i_m)) )*Rq+ &
         sin( dot_product(qvec,position(:,i_x,i_y,i_z,i_m)) )*Iq)
         enddo
      enddo
   enddo
enddo
deallocate(position)

!Call my_lattice%get_pos_mag(pos_new)
!pos_new_flat(1:3,1:size(pos_new)/3)=>pos_new
!mag_point(1:3,1:size(pos_new)/3)=>my_lattice%M%modes
!do i=1,size_mag
!    mag_point(:,i)=(cos(dot_product(qvec,pos_new_flat(:,i)))*Rq+ &
!                    sin(dot_product(qvec,pos_new_flat(:,i)))*Iq)
!enddo
!nullify(pos_new_flat,mag_point)
!deallocate(pos_new)

end subroutine 

end module m_init_spiral
