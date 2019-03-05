! Program  : gyre_force
! Purpose  : forced oscillation code
!
! Copyright 2016-2019 Rich Townsend
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

program gyre_force

  ! Uses

  use core_kinds, only : WP
  use core_parallel
  use core_system

  use gyre_ad_bvp
  use gyre_bvp
  use gyre_constants
  use gyre_ext
  use gyre_evol_model
  use gyre_context
  use gyre_freq
  use gyre_grid
  use gyre_grid_factory
  use gyre_grid_par
  use gyre_mode_par
  use gyre_model
  use gyre_model_factory
  use gyre_model_par
  use gyre_nad_bvp
  use gyre_num_par
  use gyre_osc_par
  use gyre_out_par
  use gyre_output
  use gyre_rad_bvp
  use gyre_sad_bvp
  use gyre_scan
  use gyre_scan_par
  use gyre_state
  use gyre_util
  use gyre_version
  use gyre_wave

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Variables

  character(:), allocatable     :: filename
  integer                       :: unit
  type(model_par_t)             :: ml_p
  type(mode_par_t), allocatable :: md_p(:)
  type(osc_par_t), allocatable  :: os_p(:)
  type(num_par_t), allocatable  :: nm_p(:)
  type(grid_par_t), allocatable :: gr_p(:)
  type(scan_par_t), allocatable :: sc_p(:)
  type(out_par_t)               :: ot_p_ad
  type(out_par_t)               :: ot_p_nad
  class(model_t), pointer       :: ml => null()
  integer                       :: i
  type(osc_par_t)               :: os_p_sel
  type(num_par_t)               :: nm_p_sel
  type(grid_par_t)              :: gr_p_sel
  type(scan_par_t), allocatable :: sc_p_sel(:)
  type(context_t), pointer      :: cx(:) => null()
  real(WP), allocatable         :: omega(:)
  type(grid_t)                  :: gr
  class(r_bvp_t), allocatable   :: bp_sad
  class(r_bvp_t), allocatable   :: bp_ad
  class(c_bvp_t), allocatable   :: bp_nad
  integer                       :: n_wv_ad
  integer                       :: d_wv_ad
  type(wave_t), allocatable     :: wv_ad(:)
  integer                       :: n_wv_nad
  integer                       :: d_wv_nad
  type(wave_t), allocatable     :: wv_nad(:)

  ! Read command-line arguments

  $ASSERT(n_arg() == 1,Syntax: gyre_force <filename>)

  call get_arg(1, filename)

  ! Initialize

  call init_parallel()

  call set_log_level($str($LOG_LEVEL))

  if (check_log_level('INFO')) then

     write(OUTPUT_UNIT, 100) form_header('gyre_force ['//VERSION//']', '=')
100  format(A)

     write(OUTPUT_UNIT, 110) 'Compiler         :', COMPILER_VERSION()
     write(OUTPUT_UNIT, 110) 'Compiler options :', COMPILER_OPTIONS()
110  format(A,1X,A)

     write(OUTPUT_UNIT, 120) 'OpenMP Threads   :', OMP_SIZE_MAX
120  format(A,1X,I0)
     
     write(OUTPUT_UNIT, 110) 'Input filename   :', filename

  endif

  ! Read the namelist file

  open(NEWUNIT=unit, FILE=filename, STATUS='OLD')

  call read_constants(unit)

  call read_model_par(unit, ml_p)
  call read_mode_par(unit, md_p)
  call read_osc_par(unit, os_p)
  call read_num_par(unit, nm_p)
  call read_grid_par(unit, gr_p)
  call read_scan_par(unit, sc_p)
  call read_out_par(unit, 'ad', ot_p_ad)
  call read_out_par(unit, 'nad', ot_p_nad)

  ! Initialize the model

  if (check_log_level('INFO')) then
     write(OUTPUT_UNIT, 100) form_header('Model Init', '=')
  endif

  ml => model_t(ml_p)

  ! Allocate the contexts array (will be initialized later on)

  allocate(cx(SIZE(md_p)))

  ! Loop through md_p

  d_wv_ad = 128
  n_wv_ad = 0

  allocate(wv_ad(d_wv_ad))

  d_wv_nad = 128
  n_wv_nad = 0

  allocate(wv_nad(d_wv_nad))

  md_p_loop : do i = 1, SIZE(md_p)

     if (check_log_level('INFO')) then

        write(OUTPUT_UNIT, 100) form_header('Mode Search', '=')

        write(OUTPUT_UNIT, 100) 'Mode parameters'

        write(OUTPUT_UNIT, 130) 'l :', md_p(i)%l
        write(OUTPUT_UNIT, 130) 'm :', md_p(i)%m
130     format(3X,A,1X,I0)

        write(OUTPUT_UNIT, *)

     endif

     ! Select parameters according to tags

     call select_par(os_p, md_p(i)%tag, os_p_sel)
     call select_par(nm_p, md_p(i)%tag, nm_p_sel)
     call select_par(gr_p, md_p(i)%tag, gr_p_sel)
     call select_par(sc_p, md_p(i)%tag, sc_p_sel)

     ! Set up the context

     cx(i) = context_t(ml, gr_p_sel, md_p(i), os_p_sel)

     if (md_p(i)%static) then

        ! Static modes

        ! Set up the grid

        gr = ml%grid()

        ! Calculate wavefunctions

        if (os_p_sel%adiabatic) then

           allocate(bp_sad, SOURCE=sad_bvp_t(cx(i), gr, md_p(i), nm_p_sel, os_p_sel))

           call eval_wave_sad()

           deallocate(bp_sad)

        endif

        if (os_p_sel%nonadiabatic) then

           $ABORT(Static nonadiabatic modes not currently implemented)

        endif

     else

        ! Non-static modes
     
        ! Set up the frequency array

        call build_scan(cx(i), md_p(i), os_p_sel, sc_p_sel, omega)

        if (SIZE(omega) < 2) then

           if (check_log_level('INFO')) then
              write(OUTPUT_UNIT, 100) 'Scan is empty, skipping mode...'
           endif
           
           cycle md_p_loop

        endif

        ! Create the grid

        gr = grid_t(cx(i), omega, gr_p_sel)

        ! Calculate wavefunctions

        if (os_p_sel%adiabatic) then

           if (md_p(i)%l == 0 .AND. os_p_sel%reduce_order) then
              allocate(bp_ad, SOURCE=rad_bvp_t(cx(i), gr, md_p(i), nm_p_sel, os_p_sel))
           else
              allocate(bp_ad, SOURCE=ad_bvp_t(cx(i), gr, md_p(i), nm_p_sel, os_p_sel))
           endif
           
           call eval_wave_ad(omega)

           deallocate(bp_ad)

        end if

        if (os_p_sel%nonadiabatic) then

           allocate(bp_nad, SOURCE=nad_bvp_t(cx(i), gr, md_p(i), nm_p_sel, os_p_sel))
           
           call eval_wave_nad(omega)

           deallocate(bp_nad)

        endif

     end if

  end do md_p_loop

  ! Write summary files

  call write_summary(wv_ad(:n_wv_ad), ot_p_ad)
  call write_summary(wv_nad(:n_wv_nad), ot_p_nad)

  ! Clean up

  deallocate(ml)

  ! Finish

  close(unit)

  call final_parallel()

contains

  subroutine eval_wave_sad ()

    real(WP)        :: w_i(bp_sad%n_i)
    real(WP)        :: w_o(bp_sad%n_o)
    type(r_state_t) :: st

    ! Set up the inhomogeneous boundary terms

    w_i = 0._WP
         
    w_o(1) = -1._WP
         
    n_wv_ad = n_wv_ad + 1

    if (n_wv_ad > d_wv_ad) then
       d_wv_ad = 2*d_wv_ad
       call reallocate(wv_ad, [d_wv_ad])
    endif

    associate (wv => wv_ad(n_wv_ad))

      ! Solve for the wave function

      st = r_state_t(0._WP)
       
      select type (bp_sad)
      type is (sad_bvp_t)
         wv = wave_t(bp_sad, st, w_i, w_o, n_wv_nad)
      class default
         $ABORT(Invalid bp_sad class)
      end select

      ! Write it

      call write_details(wv, ot_p_ad)

      ! If necessary, prune it

      if (ot_p_ad%prune_details) call wv%prune()

    end associate

    ! Finish

    return

  end subroutine eval_wave_sad

  !****

  subroutine eval_wave_ad (omega)

    real(WP), intent(in) :: omega(:)

    real(WP)        :: w_i(bp_ad%n_i)
    real(WP)        :: w_o(bp_ad%n_o)
    integer         :: j
    type(r_state_t) :: st

    ! Set up the inhomogeneous boundary terms

    w_i = 0._WP
         
    w_o = 0._WP
    w_o(2) = 1._WP
         
    ! Scan over frequencies

    omega_loop : do j = 1, SIZE(omega)

       n_wv_ad = n_wv_ad + 1

       if (n_wv_ad > d_wv_ad) then
          d_wv_ad = 2*d_wv_ad
          call reallocate(wv_ad, [d_wv_ad])
       endif

       associate (wv => wv_ad(n_wv_ad))

         ! Solve for the wave function

         st = r_state_t(omega(j))
       
         select type (bp_ad)
         type is (ad_bvp_t)
            wv = wave_t(bp_ad, st, w_i, w_o, n_wv_ad)
         type is (rad_bvp_t)
            wv = wave_t(bp_ad, st, w_i, w_o, n_wv_ad)
         class default
            $ABORT(Invalid bp_ad class)
         end select

         ! Write it 

         call write_details(wv, ot_p_ad)

         ! If necessary, prune it

         if (ot_p_ad%prune_details) call wv%prune()

       end associate

    end do omega_loop

    ! Finish

    return

  end subroutine eval_wave_ad

  !****

  subroutine eval_wave_nad (omega)

    real(WP), intent(in) :: omega(:)

    complex(WP)     :: w_i(bp_nad%n_i)
    complex(WP)     :: w_o(bp_nad%n_o)
    integer         :: j
    type(c_state_t) :: st

    ! Set up the inhomogeneous boundary terms

    w_i = 0._WP
         
    w_o = 0._WP
    w_o(2) = 1._WP
         
    ! Scan over frequencies

    omega_loop : do j = 1, SIZE(omega)

       n_wv_nad = n_wv_nad + 1

       if (n_wv_nad > d_wv_nad) then
          d_wv_nad = 2*d_wv_nad
          call reallocate(wv_nad, [d_wv_nad])
       endif

       associate (wv => wv_nad(n_wv_nad))

         ! Solve for the wave function

         st = c_state_t(CMPLX(omega(j), KIND=WP))
       
         select type (bp_nad)
         type is (nad_bvp_t)
            wv = wave_t(bp_nad, st, w_i, w_o, n_wv_nad)
         class default
            $ABORT(Invalid bp_nad class)
         end select

         ! Write it

         call write_details(wv, ot_p_nad)

         ! If necessary, prune it

         if (ot_p_nad%prune_details) call wv%prune()

       end associate

    end do omega_loop

    ! Finish

    return

  end subroutine eval_wave_nad

end program gyre_force
