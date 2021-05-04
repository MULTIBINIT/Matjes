module m_MCstep
use m_derived_types, only : lattice
use m_mc_track_val, only: track_val
use m_sampling, only: sphereft,equirep
use m_choose_spin, only: choose_spin
use m_relaxtyp,only: underrelax,overrelax
use m_H_public, only: t_H,energy_single
use m_hamiltonian_collection, only: hamiltonian

private
public :: MCstep
contains
!
! ===============================================================
!
SUBROUTINE MCstep(lat,io_MC,N_spin,state_prop,kt,H)
    use m_constants, only : k_b,pi
    use m_MC_io,only: MC_input
    Implicit none
    ! input
    type(lattice),intent(inout)         :: lat
    type(MC_input),intent(in)           :: io_MC 
    real(8), intent(in)                 :: kt
    integer, intent(in)                 :: N_spin
    type(track_val),intent(inout)       :: state_prop
    type(hamiltonian), intent(inout)    :: H
    
    ! internal variable
    real(8) :: E_old        !energy caused by the i_spin-site with S_old 
    real(8) :: E_new        !energy caused by the i_spin-site with S_new
    real(8) :: S_old(3)     !old spin direction at chosen state
    real(8) :: S_new(3)     !new spin direction at chosen state
    real(8) :: Dmag(3)      !change of magnetization caused by S_new at i_spin 
    real(8) :: DE           !Energy difference caused by changes spin
    integer :: i_spin       !chosen spin index (1:N_cell*nmag)
    integer :: i_site       !unit cell index of chosen spin index
    integer :: i_spin_uc    !spin index within unit-cell

    !choose the spin-site which is to be modified
    call choose_spin(i_spin,N_spin)
    i_site=(i_spin-1)/lat%nmag+1
    i_spin_uc= modulo((i_spin-1),lat%nmag)+1
    state_prop%dim_bnd(:,1)=[(i_spin_uc-1)*3+1,i_spin_uc*3]  !1 has to be magnetic moment order parameter

    !----------------------------------
    !       Calculate the energy difference if this was flipped
    !       and decider, if the Spin flip will be performed
    !----------------------------------
    !get Energy of old configuration
    S_old=lat%M%modes_3(:,i_spin)
    E_old=H%energy_single(i_site,state_prop%dim_bnd,lat)
    
    !get Energy of the new configuration
    S_new=state_prop%spin_sample(i_spin,lat,H)  !choose new magnetic direction
    lat%M%modes_3(:,i_spin)=S_new               !set new configuration
    E_new=H%energy_single(i_site,state_prop%dim_bnd,lat)
    lat%M%modes_3(:,i_spin)=S_old   !revert for now to old state

    !! get energy difference
    DE=E_new-E_old
    
    state_prop%nb=state_prop%nb+1.0d0
    if ( accept(kt,DE) ) then
        Dmag=-S_old+S_new   !change of magnetization
        ! update the spin
        lat%M%modes_3(:,i_spin)=S_new
        ! update the quantities
        state_prop%E_total=state_prop%E_total+DE
        state_prop%Magnetization=state_prop%Magnetization+Dmag
        state_prop%acc=state_prop%acc+1.0d0
    endif
   
    state_prop%rate=state_prop%acc/state_prop%nb
END SUBROUTINE MCstep
! ===============================================================

function accept(kt,DE)
    use m_get_random, only: get_rand_classic
    real(8),intent(in)  :: kt,DE

    real(8) :: choice, tmp
    logical :: accept

    accept=dE<0.0d0     !accept all energy gains
    if(.not.accept)then
        !check with temperature if energy loss is accepted
        tmp=-DE/kT
        tmp=max(tmp,-200.0d0) !prevent exp(tmp) underflow
        choice=get_rand_classic()
        accept=Choice.lt.exp(tmp)
    endif
end function
end module
