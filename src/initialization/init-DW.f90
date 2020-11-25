module m_init_DW
use m_derived_types
implicit none
private
public :: init_DW
interface init_DW
    module procedure init_DW_old
    module procedure init_DW_new
end interface

contains


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Initialize the starting configuration as a domain wall along the x direction
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


subroutine init_DW_new(io,fname,lat,ordname,dim_mode,state)
    use m_io_utils, only: get_parameter
    use m_init_util, only: get_pos_vec
    use m_constants, only : pi
    integer,intent(in)              :: io       !init-file io-unit
    character(*),intent(in)         :: fname    !init-file name 
    type(lattice), intent(in)       :: lat      !entire lattice containing geometric information
    character(*),intent(in)         :: ordname  !name of the order parameter
    integer,intent(in)              :: dim_mode !dimension of the order parameter in each cell
    real(8),pointer,intent(inout)   :: state(:) !pointer the the order parameter
    ! internal variables
    real(8),allocatable,target :: pos(:)
    real(8),pointer :: pos_3(:,:),state_3(:,:)
    real(8)         :: dw_pos(3),normal(3)  !position on domain wall, normal to domain wall
    real(8),allocatable :: dist(:)
    integer             :: i
    real(8)             :: length       !length of domain wall
    
    dw_pos=lat%a_sc(1,:)*0.5d0
    normal=[lat%areal(2,2),-lat%areal(2,1),0.0d0]
    normal=normal/norm2(normal)
    length=10*norm2(lat%areal(1,:))

    Call get_pos_vec(lat,dim_mode,ordname,pos)
    pos_3(1:3,1:size(pos)/3)=>pos
    state_3(1:3,1:size(pos)/3)=>state

    allocate(dist(size(pos_3,2)),source=0.0d0)
    do i=1,size(pos_3,2)
        pos_3(:,i)=pos_3(:,i)-dw_pos
        dist(i)=dot_product(pos_3(:,i),normal)
        state_3(:,i)=dist(i)
    enddo

    dist=dist*pi/length
    dist=dist+0.5d0*pi

    state=0.d0
    do i=1,size(dist)
        if(dist(i)>=pi)then
            state_3(3,i)=1.0d0
        elseif(dist(i)<=0)then
            state_3(3,i)=-1.0d0
        else
           state_3(1,i)=sin(dist(i))
           state_3(2,i)=0.0d0
           state_3(3,i)=-1.0d0*cos(dist(i))
        endif
    enddo
    
    nullify(pos_3,state_3)
    deallocate(pos)
end subroutine


subroutine init_DW_old(my_lattice,my_motif,start,end)
type (lattice), intent(inout) :: my_lattice
type(t_cell), intent(in) :: my_motif
integer, intent(in) ::  start,end
! internal variables
integer :: i_z,i_y,i_x,i_m,Nx,Ny,Nz,size_mag,dw_position,i_w,shape_lattice(4)
real(kind=8) :: alpha

! get the position of the sites on the lattice
Nx=my_lattice%dim_lat(1)
Ny=my_lattice%dim_lat(2)
Nz=my_lattice%dim_lat(3)
shape_lattice=shape(my_lattice%ordpar%l_modes)
size_mag=shape_lattice(4)

do i_x=1,Nx
   if ( (2*i_x/Nx) == 1) then
      dw_position=i_x
      exit
   endif
enddo

do i_x=1,Nx
   do i_w=-4,4
      alpha=real(5+i_w,8)/10.0d0*acos(-1.0d0)
      if ( i_x+i_w == dw_position ) then
         do i_y=1,Ny
            do i_z=1,Nz
               do i_m=1,size_mag

           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(start)=sin(alpha)
           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(start+1)=0.0d0
           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(end)=-1.0d0*cos(alpha)

               enddo
            enddo
         enddo

      elseif ( i_x+i_w .gt. dw_position ) then
         do i_y=1,Ny
            do i_z=1,Nz
               do i_m=1,size_mag

           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(start:start+1)=0.0d0
           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(end)=-1.0d0

               enddo
            enddo
         enddo

      else
         do i_y=1,Ny
            do i_z=1,Nz
               do i_m=1,size_mag

           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(start:start+1)=0.0d0
           my_lattice%ordpar%l_modes(i_x,i_y,i_z,i_m)%w(end)=1.0d0

               enddo
            enddo
         enddo
      endif
   enddo
enddo

end subroutine

end module m_init_DW
