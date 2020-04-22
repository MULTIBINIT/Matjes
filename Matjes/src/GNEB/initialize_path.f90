module m_initialize_path
use m_gneb_parameters
use m_io_gneb
use m_derived_types, only : point_shell_Operator,io_parameter
use m_basic_types, only : vec_point
use m_modes_variables, only : point_shell_mode
use m_rotation, only : rotation_axis
use m_convert
use m_path
use m_operator_pointer_utils
use m_write_spin
use m_createspinfile
use m_energyfield
use m_minimize

contains

subroutine path_initialization(path,io_simu)
implicit none
type(io_parameter), intent(in) :: io_simu
real(kind=8), intent(inout) :: path(:,:,:)
! internal variable
integer :: shape_path(3)
integer :: i_nim,nim,N_cell
logical :: exists=.False.,found=.False.
character(35) :: num
!!!!!!!!!!! allocate the pointers to find the path
type(vec_point),allocatable,dimension(:,:) :: all_mode_path

shape_path=shape(path)
nim=shape_path(3)
N_cell=shape_path(2)

! initialize all pointers
allocate(all_mode_path(N_cell,nim))

do i_nim=1,nim
   call associate_pointer(all_mode_path(:,i_nim),path(:,:,i_nim),'magnetic',found)
enddo

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!! allocate the pointers for the B-field and the energy
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

if (initpath==2) then
   write (6,'(a)') "Initial guess for the path from file "
   call read_path(trim(adjustl(restartfile_path)),amp_rnd_path,path,exists)
   if (exists) then
       num=convert(nim)
       momfile_i = trim(adjustl(restartfile_path))//'_1.dat'
       momfile_f = trim(adjustl(restartfile_path))//'_'//trim(adjustl(num))//'.dat'
       call read_inifin(trim(adjustl(momfile_i)),trim(adjustl(momfile_f)),amp_rnd,path)
       call WriteSpinAndCorrFile(path(:,:,1),'SpinSTM_GNEB_ini.dat')
       call CreateSpinFile(path(:,:,1),'povray_GNEB_ini.dat')
       call WriteSpinAndCorrFile(path(:,:,nim),'SpinSTM_GNEB_fin.dat')
       call CreateSpinFile(path(:,:,nim),'povray_GNEB_fin.dat')

       write (*,'(a)') "Relaxing the first image..."

       call minimize(all_mode_path(:,1),io_simu)
       write (*,'(a)') "Done!"

       write (*,'(a)') "Relaxing the last image..."
       call minimize(all_mode_path(:,nim),io_simu)
       write (*,'(a)') "Done!"

   else
     call read_inifin(trim(adjustl(momfile_i)),trim(adjustl(momfile_f)),amp_rnd,path)
     call WriteSpinAndCorrFile(path(:,:,1),'SpinSTM_GNEB_ini.dat')
     call CreateSpinFile(path(:,:,1),'povray_GNEB_ini.dat')
     call WriteSpinAndCorrFile(path(:,:,nim),'SpinSTM_GNEB_fin.dat')
     call CreateSpinFile(path(:,:,nim),'povray_GNEB_fin.dat')

     write (*,'(a)') "Relaxing the first image..."
     call minimize(all_mode_path(:,1),io_simu)
     write (*,'(a)') "Done!"

     write (*,'(a)') "Relaxing the last image..."
     call minimize(all_mode_path(:,nim),io_simu)
     write (*,'(a)') "Done!"


     call geodesic_path(amp_rnd_path,path)
     write (*,'(a)') "Geodesic path generated"
   end if
else
   call read_inifin(trim(adjustl(momfile_i)),trim(adjustl(momfile_f)),amp_rnd,path)
   call WriteSpinAndCorrFile(path(:,:,1),'SpinSTM_GNEB_ini.dat')
   call CreateSpinFile(path(:,:,1),'povray_GNEB_ini.dat')
   call WriteSpinAndCorrFile(path(:,:,nim),'SpinSTM_GNEB_fin.dat')
   call CreateSpinFile(path(:,:,nim),'povray_GNEB_fin.dat')

   write (*,'(a)') "Relaxing the first image..."

   call minimize(all_mode_path(:,1),io_simu)
   write (*,'(a)') "Done!"

   write (*,'(a)') "Relaxing the last image..."
   call minimize(all_mode_path(:,nim),io_simu)
   write (*,'(a)') "Done!"

   call geodesic_path(amp_rnd_path,path)
   write (*,'(a)') "Geodesic path generated"
end if

end subroutine path_initialization

end module m_initialize_path
