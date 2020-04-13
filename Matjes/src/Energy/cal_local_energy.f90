module m_local_energy
use m_derived_types, only : point_shell_Operator
use m_modes_variables, only : point_shell_mode

interface local_energy
   module procedure local_energy_pointer
end interface local_energy

private
public :: local_energy,local_energy_pointer_EDestrib

contains

subroutine local_energy_pointer(E_int,iomp,spin,E_line)
use m_energy_commons
use m_dipole_energy
use m_dipolar_field, only : i_dip
implicit none
! input
type(point_shell_mode), intent(in) :: spin
type(point_shell_Operator), intent(in) :: E_line
integer, intent(in) :: iomp
! ouput
real(kind=8), intent(out) :: E_int
! internal
integer :: i,N,j

N=size(spin%shell)
E_int=0.0d0

do i=1,N

   E_int=E_int+dot_product( spin%shell(1)%w , matmul(E_line%shell(i)%Op_loc,spin%shell(i)%w) )

   write(*,*) spin%shell(1)%w
   do j=1,9
   write(*,*) E_line%shell(i)%Op_loc(:,j)
   enddo
   write(*,*) spin%shell(i)%w
   write(*,*) ''

enddo

pause
if (i_dip) E_int=E_int+get_dipole_E(iomp)

end subroutine local_energy_pointer

subroutine local_energy_pointer_EDestrib(E_int,iomp,spin,E_line,S_0)
use m_energy_commons
use m_dipole_energy
implicit none
! input
type(point_shell_mode), intent(in) :: spin
type(point_shell_Operator), intent(in) :: E_line
real(kind=8), intent(in) :: S_0(:)
integer, intent(in) :: iomp
! ouput
real(kind=8), intent(out) :: E_int
! internal
integer :: i,N

N=size(spin%shell)
E_int=0.0d0

do i=1,N

   E_int=E_int+dot_product( S_0 , matmul(E_line%shell(i)%Op_loc,spin%shell(i)%w) )

enddo

end subroutine local_energy_pointer_EDestrib

end module m_local_energy
