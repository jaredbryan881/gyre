! Module   : gyre_detail
! Purpose  : detailed output
!
! Copyright 2020-2021 Rich Townsend & The GYRE Team
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'
$include 'gyre_detail.inc'

module gyre_detail

  ! Uses

  use core_kinds

  use gyre_context
  use gyre_constants
  use gyre_evol_model
  use gyre_freq
  use gyre_grid
  use gyre_hdf_writer
  use gyre_mode
  use gyre_model
  use gyre_out_par
  use gyre_out_util
  use gyre_resp
  use gyre_state
  use gyre_txt_writer
  use gyre_util
  use gyre_wave
  use gyre_writer

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  type :: detail_t
     private
     type(out_par_t) :: ot_p
   contains
     procedure, public :: write
  end type detail_t

  ! Interfaces

  interface detail_t
     module procedure detail_t_
  end interface detail_t

  ! Access specifiers

  private

  public :: detail_t

contains

  function detail_t_ (ot_p) result (dt)

    type(out_par_t), intent(in) :: ot_p
    type(detail_t)              :: dt

    ! Construct the detail_t

    dt%ot_p = ot_p

    ! Finish

  end function detail_t_

  !****

  subroutine write (this, wv)

    class(detail_t), intent(inout) :: this
    class(wave_t), intent(in)      :: wv

    character(:), allocatable        :: detail_file
    class(writer_t), allocatable     :: wr
    character(ITEM_LEN), allocatable :: items(:)
    type(context_t)                  :: cx
    class(model_t), pointer          :: ml
    type(c_state_t)                  :: st
    type(grid_t)                     :: gr
    integer                          :: i
    logical                          :: written

    ! Write a detail file

    if (this%ot_p%detail_template == '' .OR. &
        this%ot_p%detail_item_list == '' .OR. &
        filter_wave(wv, this%ot_p%detail_filter_list)) return

    ! Set up the filename

    detail_file = this%ot_p%detail_template

    detail_file = subst(detail_file, '%ID', wv%id, '(I5.5)')
    detail_file = subst(detail_file, '%L', wv%l, '(I3.3)')
    detail_file = subst(detail_file, '%M', wv%m, '(SP,I3.2)')
    detail_file = subst(detail_file, '%id', wv%id, '(I0)')
    detail_file = subst(detail_file, '%l', wv%l, '(I0)')
    detail_file = subst(detail_file, '%m', wv%m, '(SP,I0)')

    select type (wv)
    class is (mode_t)
       detail_file = subst(detail_file, '%N', wv%n_pg, '(SP,I6.5)')
       detail_file = subst(detail_file, '%n', wv%n_pg, '(SP,I0)')
       detail_file = subst(detail_file, '%P', wv%n_p, '(SP,I6.5)')
       detail_file = subst(detail_file, '%p', wv%n_p, '(SP,I0)')
       detail_file = subst(detail_file, '%G', wv%n_g, '(SP,I6.5)')
       detail_file = subst(detail_file, '%g', wv%n_g, '(SP,I0)')
    end select

    ! Open the file

    select case (this%ot_p%detail_file_format)
    case ('HDF')
       allocate(wr, SOURCE=hdf_writer_t(detail_file, this%ot_p%label))
    case ('TXT')
       allocate(wr, SOURCE=txt_writer_t(detail_file, this%ot_p%label))
    case default
       $ABORT(Invalid detail_file_format)
    end select
    
    ! Split the item list

    items = split_list(this%ot_p%detail_item_list, ',')

    ! Write the items

    cx = wv%context()
    ml => cx%model()

    st = wv%state()
    gr = wv%grid()

    item_loop : do i = 1, SIZE(items)

       call write_wave_(items(i), this%ot_p, wv, gr, wr, written)
       if (written) cycle item_loop

       call write_context_(items(i), this%ot_p, cx, gr, st, wr, written)
       if (written) cycle item_loop

       call write_model_(items(i), this%ot_p, ml, gr, wv%l, wr, written)
       if (written) cycle item_loop

       ! Indicate a problem with the writing

       write(ERROR_UNIT, *) 'Ignoring missing/invalid detail item:', TRIM(items(i))

    end do item_loop

    ! Close the file

    call wr%final()

    ! Finish

  end subroutine write

  !****

  subroutine write_wave_ (item, ot_p, wv, gr, wr, written)

    character(*), intent(in)       :: item
    type(out_par_t), intent(in)    :: ot_p
    class(wave_t), intent(in)      :: wv
    type(grid_t), intent(in)       :: gr
    class(writer_t), intent(inout) :: wr
    logical, intent(out)           :: written

    integer :: j

    ! Write the item from wave_t data

    written = .TRUE.

    select case (item)

    case ('n')

       call wr%write('n', wv%n)

    case ('id')

       call wr%write('id', wv%id)

    case ('l')

       call wr%write('l', wv%l)

    case ('l_i')

       call wr%write('l_i', wv%l_i)

    case ('m')

       call wr%write('m', wv%m)

    case ('omega')

       call wr%write('omega', wv%omega)

    case ('omega_int')

       call wr%write('omega_int', wv%omega_int())

    case ('domega_rot')

       call wr%write('domega_rot', wv%domega_rot())

    case ('freq')

       call wr%write('freq', wv%freq(ot_p%freq_units, ot_p%freq_frame))

    case ('dfreq_rot')

       call wr%write('dfreq_rot', wv%dfreq_rot(ot_p%freq_units))

    case ('freq_units')

       call wr%write('freq_units', ot_p%freq_units)

    case ('freq_frame')

       call wr%write('freq_frame', ot_p%freq_frame)

    case ('eta')

       call wr%write('eta', wv%eta())

    case ('f_T')

       call wr%write('f_T', wv%f_T())

    case ('f_g')

       call wr%write('f_g', wv%f_g())

    case ('psi_T')

       call wr%write('psi_T', wv%psi_T())

    case ('psi_g')

       call wr%write('psi_g', wv%psi_g())

    case ('E')

       call wr%write('E', wv%E())

    case ('E_p')

       call wr%write('E_p', wv%E_p())

    case ('E_g')

       call wr%write('E_g', wv%E_g())

    case ('E_norm')

       call wr%write('E_norm', wv%E_norm())

    case ('E_ratio')

       call wr%write('E_ratio', wv%E_ratio())

    case ('H')

       call wr%write('H', wv%H())

    case ('W')

       call wr%write('W', wv%W())

    case ('W_eps')

       call wr%write('W_eps', wv%W_eps())

    case ('tau_ss')

       call wr%write('tau_ss', wv%tau_ss())

    case ('tau_tr')

       call wr%write('tau_tr', wv%tau_tr())

    case ('beta')

       call wr%write('beta', wv%beta())

    case ('x')

       call wr%write('x', gr%pt%x)

    case ('x_ref')

       call wr%write('x_ref', gr%pt(wv%j_ref)%x)

    $WRITE_POINTS(lambda,wv%lambda(j))
    $WRITE_POINTS(y_1,wv%y_i(1, j))
    $WRITE_POINTS(y_2,wv%y_i(2, j))
    $WRITE_POINTS(y_3,wv%y_i(3, j))
    $WRITE_POINTS(y_4,wv%y_i(4, j))
    $WRITE_POINTS(y_5,wv%y_i(5, j))
    $WRITE_POINTS(y_6,wv%y_i(6, j))
    $WRITE_POINTS(xi_r,wv%xi_r(j))
    $WRITE_POINTS(xi_h,wv%xi_h(j))
    $WRITE_POINTS(eul_phi,wv%eul_phi(j))
    $WRITE_POINTS(deul_phi,wv%deul_phi(j))
    $WRITE_POINTS(eul_P,wv%eul_P(j))
    $WRITE_POINTS(eul_rho,wv%eul_rho(j))
    $WRITE_POINTS(eul_T,wv%eul_T(j))
    $WRITE_POINTS(lag_P,wv%lag_P(j))
    $WRITE_POINTS(lag_rho,wv%lag_rho(j))
    $WRITE_POINTS(lag_T,wv%lag_T(j))
    $WRITE_POINTS(lag_S,wv%lag_S(j))
    $WRITE_POINTS(lag_L,wv%lag_L(j))
    $WRITE_POINTS(dE_dx,wv%dE_dx(j))
    $WRITE_POINTS(dW_dx,wv%dW_dx(j))
    $WRITE_POINTS(dW_eps_dx,wv%dW_eps_dx(j))
    $WRITE_POINTS(dzeta_dx,wv%dzeta_dx(j))
    $WRITE_POINTS(dzeta_dm,wv%dzeta_dm(j))
    $WRITE_POINTS(dbeta_dx,wv%dbeta_dx(j))
    $WRITE_POINTS(dtau_ss_dx,wv%dtau_ss_dx(j))
    $WRITE_POINTS(dtau_tr_dx,wv%dtau_tr_dx(j))
    $WRITE_POINTS(Yt_1,wv%Yt_1(j))
    $WRITE_POINTS(Yt_2,wv%Yt_2(j))
    $WRITE_POINTS(I_0,wv%I_0(j))
    $WRITE_POINTS(I_1,wv%I_1(j))
    $WRITE_POINTS(alpha_0,wv%alpha_0(j))
    $WRITE_POINTS(alpha_1,wv%alpha_1(j))
    $WRITE_POINTS(prop_type,wv%prop_type(j))

    $WRITE_REF(xi_r_ref,wv%xi_r(wv%j_ref))
    $WRITE_REF(xi_h_ref,wv%xi_h(wv%j_ref))
    $WRITE_REF(eul_phi_ref,wv%eul_phi(wv%j_ref))
    $WRITE_REF(deul_phi_ref,wv%deul_phi(wv%j_ref))
    $WRITE_REF(lag_S_ref,wv%lag_S(wv%j_ref))
    $WRITE_REF(lag_L_ref,wv%lag_L(wv%j_ref))

    case default

       select type (wv)

       class is (mode_t)

          call write_mode_(item, ot_p, wv, gr, wr, written)

       class is (resp_t)

          call write_resp_(item, ot_p, wv, gr, wr, written)

       class default

          written = .FALSE.

       end select

    end select

    ! Finish

    return

  end subroutine write_wave_
      
  !****

  subroutine write_mode_ (item, ot_p, md, gr, wr, written)

    character(*), intent(in)       :: item
    type(out_par_t), intent(in)    :: ot_p
    class(mode_t), intent(in)      :: md
    type(grid_t), intent(in)       :: gr
    class(writer_t), intent(inout) :: wr
    logical, intent(out)           :: written

    ! Write the item from mode_t data

    written = .TRUE.

    select case (item)

    case ('n_p')

       call wr%write('n_p', md%n_p)

    case ('n_g')

       call wr%write('n_g', md%n_g)

    case ('n_pg')

       call wr%write('n_pg', md%n_pg)

    case default

       written = .FALSE.
         
    end select

    ! Finish

    return

  end subroutine write_mode_

  !****

  subroutine write_resp_ (item, ot_p, rs, gr, wr, written)

    character(*), intent(in)       :: item
    type(out_par_t), intent(in)    :: ot_p
    class(resp_t), intent(in)      :: rs
    type(grid_t), intent(in)       :: gr
    class(writer_t), intent(inout) :: wr
    logical, intent(out)           :: written

    integer :: j

    ! Write the item from resp_t data

    written = .TRUE.

    select case (item)

    case ('Omega_orb')

       call wr%write('Omega_orb', rs%or_p%Omega_orb)

    case ('k')

       call wr%write('k', rs%fr_p%k)

    case ('F')

       call wr%write('F', rs%F())

    case ('J_dot')

       call wr%write('J_dot', rs%J_dot())

    $WRITE_POINTS(eul_psi,rs%eul_psi(j))
    $WRITE_POINTS(phi_2,rs%phi_2(j))

    $WRITE_REF(eul_psi_ref,rs%eul_psi(rs%j_ref))
    $WRITE_REF(phi_2_ref,rs%phi_2(rs%j_ref))

    case default

       written = .FALSE.

    end select

    ! Finish

    return

  end subroutine write_resp_

  !****

  subroutine write_context_ (item, ot_p, cx, gr, st, wr, written)

    character(*), intent(in)       :: item
    type(out_par_t), intent(in)    :: ot_p
    class(context_t), intent(in)   :: cx
    type(grid_t), intent(in)       :: gr
    type(c_state_t), intent(in)    :: st
    class(writer_t), intent(inout) :: wr
    logical, intent(out)           :: written

    integer :: j

    ! Write the item from context_t data

    written = .TRUE.

    select case (item)

    $WRITE_POINTS(eps_rho,cx%eps_rho(st, gr%pt(j)))
    $WRITE_POINTS(eps_T,cx%eps_T(st, gr%pt(j)))
    $WRITE_POINTS(Omega_rot,cx%Omega_rot(gr%pt(j)))

    case default

       written = .FALSE.

    end select

    ! Finish

    return

  end subroutine write_context_

  !****

  subroutine write_model_ (item, ot_p, ml, gr, l, wr, written)

    character(*), intent(in)            :: item 
    type(out_par_t), intent(in)         :: ot_p
    class(model_t), pointer, intent(in) :: ml
    type(grid_t), intent(in)            :: gr
    integer, intent(in)                 :: l
    class(writer_t), intent(inout)      :: wr
    logical, intent(out)                :: written

    integer :: j

    ! Write the item from model_t data

    written = .TRUE.

    select case (item)

    case ('Delta_p')

       call wr%write('Delta_p', ml%Delta_p(gr%x_i(), gr%x_o()))

    case ('Delta_g')

       call wr%write('Delta_g', ml%Delta_g(gr%x_i(), gr%x_o(), l*(l+1._WP)))

    $WRITE_POINTS(V_2,ml%coeff(I_V_2, gr%pt(j)))
    $WRITE_POINTS(As,ml%coeff(I_AS, gr%pt(j)))
    $WRITE_POINTS(U,ml%coeff(I_U, gr%pt(j)))
    $WRITE_POINTS(c_1,ml%coeff(I_C_1, gr%pt(j)))
    $WRITE_POINTS(Gamma_1,ml%coeff(I_GAMMA_1, gr%pt(j)))
    $WRITE_POINTS(nabla,ml%coeff(I_NABLA, gr%pt(j)))
    $WRITE_POINTS(nabla_ad,ml%coeff(I_NABLA_AD, gr%pt(j)))
    $WRITE_POINTS(dnabla_ad,ml%dcoeff(I_NABLA_AD, gr%pt(j)))
    $WRITE_POINTS(delta,ml%coeff(I_DELTA, gr%pt(j)))
    $WRITE_POINTS(c_lum,ml%coeff(I_C_LUM, gr%pt(j)))
    $WRITE_POINTS(c_rad,ml%coeff(I_C_RAD, gr%pt(j)))
    $WRITE_POINTS(c_thn,ml%coeff(I_C_THN, gr%pt(j)))
    $WRITE_POINTS(c_thk,ml%coeff(I_C_THK, gr%pt(j)))
    $WRITE_POINTS(c_eps,ml%coeff(I_C_EPS, gr%pt(j)))
    $WRITE_POINTS(kap_rho,ml%coeff(I_KAP_RHO, gr%pt(j)))
    $WRITE_POINTS(kap_T,ml%coeff(I_KAP_T, gr%pt(j)))

    case default
       
       select type (ml)

       class is (evol_model_t)

          call write_evol_model_(item, ot_p, ml, gr, l, wr, written)

       class default

          written = .FALSE.

       end select

    end select

    ! Finish

    return

  end subroutine write_model_

  !****

  subroutine write_evol_model_ (item, ot_p, ml, gr, l, wr, written)

    character(*), intent(in)                 :: item
    type(out_par_t), intent(in)              :: ot_p
    class(evol_model_t), pointer, intent(in) :: ml
    type(grid_t), intent(in)                 :: gr
    integer, intent(in)                      :: l
    class(writer_t), intent(inout)           :: wr
    logical, intent(out)                     :: written

    integer :: j
    
    ! Write the item from evol_model_t data

    written = .TRUE.

    select case (item)
       
    case ('M_star')

       call wr%write('M_star', ml%M_star)

    case ('R_star')

       call wr%write('R_star', ml%R_star)

    case ('L_star')

       call wr%write('L_star', ml%L_star)

    $WRITE_POINTS(M_r,ml%M_r(gr%pt(j)))
    $WRITE_POINTS(P,ml%P(gr%pt(j)))
    $WRITE_POINTS(rho,ml%rho(gr%pt(j)))
    $WRITE_POINTS(T,ml%T(gr%pt(j)))

    case default

       written = .FALSE.

    end select

    ! Finish

    return

  end subroutine write_evol_model_

end module gyre_detail
