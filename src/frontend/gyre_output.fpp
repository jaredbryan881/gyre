! Program  : gyre_output
! Purpose  : output routines
!
! Copyright 2013 Rich Townsend
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

module gyre_output

  ! Uses

  use core_kinds
  use core_constants

  use gyre_coeffs
  use gyre_evol_coeffs
  use gyre_poly_coeffs
  use gyre_mode
  use gyre_util
  use gyre_writer
  use gyre_hdf_writer
  use gyre_txt_writer

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Access specifiers

  private

  public :: write_data

contains

  subroutine write_data (unit, md)

    integer, intent(in)         :: unit
    type(mode_t), intent(in)    :: md(:)

    character(LEN=256)           :: freq_units
    character(LEN=FILENAME_LEN)  :: summary_file
    character(LEN=256)           :: summary_file_format
    character(LEN=2048)          :: summary_item_list
    character(LEN=FILENAME_LEN)  :: mode_prefix
    character(LEN=256)           :: mode_file_format
    character(LEN=2048)          :: mode_item_list
    character(LEN=FILENAME_LEN)  :: mode_file
    class(writer_t), allocatable :: wr
    character(LEN=16)            :: ext
    integer                      :: j

    namelist /output/ freq_units, summary_file, summary_file_format, summary_item_list, mode_prefix, mode_file_format, mode_item_list

    ! Read output parameters

    freq_units = 'NONE'

    summary_file = ''
    summary_file_format = 'HDF'
    summary_item_list = 'l,n_pg,omega,freq'

    mode_prefix = ''
    mode_file_format = 'HDF'
    mode_item_list = TRIM(summary_item_list)//',x,xi_r,xi_h'

    rewind(unit)
    read(unit, NML=output, END=900)

    ! Write output files

    if(summary_file /= '') then

       select case (summary_file_format)
       case ('HDF')
          allocate(hdf_writer_t::wr)
       case ('TXT')
          allocate(txt_writer_t::wr)
       case default
          $ABORT(Invalid summary_file_format)
       end select

       call wr%init(summary_file)
       call write_summary(wr, md, split_item_list(summary_item_list), freq_units)
       call wr%final()

       deallocate(wr)

    endif

    if(mode_prefix /= '') then

       select case (mode_file_format)
       case ('HDF')
          allocate(hdf_writer_t::wr)
          ext = '.h5'
       case ('TXT')
          allocate(txt_writer_t::wr)
          ext = '.txt'
       case default
          $ABORT(Invalid mode_file_format)
       end select

       mode_loop : do j = 1,SIZE(md)

          write(mode_file, 100) TRIM(mode_prefix), j, TRIM(ext)
100       format(A,I4.4,A)

          call wr%init(mode_file)
          call write_mode(wr, md(j), split_item_list(mode_item_list), freq_units, j)
          call wr%final()

       end do mode_loop

       deallocate(wr)
       
    end if

    ! Finish

    return

    ! Jump-in point for end-of-file

900 continue

    $ABORT(No &output namelist in input file)

  end subroutine write_data

!****

  subroutine write_summary (wr, md, items, freq_units)

    class(writer_t), intent(inout) :: wr
    type(mode_t), intent(in)       :: md(:)
    character(LEN=*), intent(in)   :: items(:)
    character(LEN=*), intent(in)   :: freq_units

    integer            :: n_md
    integer            :: i
    integer            :: n_p(SIZE(md))
    integer            :: n_g(SIZE(md))
    integer            :: n_pg(SIZE(md))
    integer            :: j

    ! Calculate summary data

    n_md = SIZE(md)

    mode_loop : do i = 1,n_md
       call md(i)%classify(n_p(i), n_g(i), n_pg(i))
    end do mode_loop

    ! Write items

    item_loop : do j = 1,SIZE(items)

       select case (items(j))

       case('l')
          call wr%write('l', md%op%l)
       case('n_p')
          call wr%write('n_p', n_p)
       case('n_g')
          call wr%write('n_g', n_g)
       case('n_pg')
          call wr%write('n_pg', n_pg)
       case('omega')
          call wr%write('omega', md%omega)
       case('freq')
          call wr%write('freq', [(md(i)%freq(freq_units), i=1,n_md)])
       case('beta')
          call wr%write('beta', [(md(i)%beta(), i=1,n_md)])
       case('E')
          call wr%write('E', [(md(i)%E(), i=1,n_md)])
       case('E_norm')
          call wr%write('E_norm', [(md(i)%E_norm(), i=1,n_md)])
       case('W')
          call wr%write('W', [(md(i)%W(), i=1,n_md)])
       case('omega_im')
          call wr%write('omega_im', [(md(i)%omega_im(), i=1,n_md)])
       case default
          if(n_md >= 1) then
             select type (cf => md(1)%cf)
             type is (evol_coeffs_t)
                call write_summary_evol(wr, cf, items(j))
             type is (poly_coeffs_t)
                call write_summary_poly(wr, cf, items(j))
             class default
                write(ERROR_UNIT, *) 'item:', TRIM(items(j))
                $ABORT(Invalid item)
             end select
          endif
       end select

    end do item_loop

    ! Finish

    return

  contains

    subroutine write_summary_evol (wr, ec, item)

      class(writer_t), intent(inout)  :: wr
      type(evol_coeffs_t), intent(in) :: ec
      character(LEN=*), intent(in)    :: item

      ! Write the item

      select case (item)
      case ('M_star')
         call wr%write('M_star', ec%M_star)
      case ('R_star')
         call wr%write('R_star', ec%R_star)
      case ('L_star')
         call wr%write('L_star', ec%L_star)
      case default
         write(ERROR_UNIT, *) 'item:', TRIM(item)
         $ABORT(Invalid item)
      end select

      ! Finish

      return

    end subroutine write_summary_evol

    subroutine write_summary_poly (wr, pc, item)

      class(writer_t), intent(inout)  :: wr
      type(poly_coeffs_t), intent(in) :: pc
      character(LEN=*), intent(in)    :: item

      ! Write the item

      select case (item)
      case ('n_poly')
         call wr%write('n_poly', pc%n_poly)
      case default
         write(ERROR_UNIT, *) 'item:', TRIM(item)
         $ABORT(Invalid item)
      end select

      ! Finish

      return

    end subroutine write_summary_poly

  end subroutine write_summary

!****

  subroutine write_mode (wr, md, items, freq_units, i)

    class(writer_t), intent(inout) :: wr
    type(mode_t), intent(in)       :: md
    character(LEN=*), intent(in)   :: items(:)
    character(LEN=*), intent(in)   :: freq_units
    integer, intent(in)            :: i

    integer        :: n_p
    integer        :: n_g
    integer        :: n_pg
    integer        :: j

    ! Calculate mode data

    call md%classify(n_p, n_g, n_pg)
    
    ! Write items

    call wr%write('i', i)

    item_loop : do j = 1,SIZE(items)

       select case (items(j))
       case ('n')
          call wr%write('n', md%n)
       case ('l')
          call wr%write('l', md%op%l)
       case ('n_p')
          call wr%write('n_p', n_p)
       case ('n_g')
          call wr%write('n_g', n_g)
       case ('n_pg')
          call wr%write('n_pg', n_pg)
       case ('omega')
          call wr%write('omega', md%omega)
       case ('freq')
          call wr%write('freq', md%freq(freq_units))
       case ('beta')
          call wr%write('beta', md%beta())
       case ('E')
          call wr%write('E', md%E())
       case ('E_norm')
          call wr%write('E_norm', md%E_norm())
       case ('W')
          call wr%write('W', md%W())
       case('omega_im')
          call wr%write('omega_im', md%omega_im())
       case ('x')
          call wr%write('x', md%x)
       case('V')
          call wr%write('V', md%cf%V(md%x))
       case('As')
          call wr%write('As', md%cf%As(md%x))
       case('U')
          call wr%write('U', md%cf%U(md%x))
       case('c_1')
          call wr%write('c_1', md%cf%c_1(md%x))
       case ('Gamma_1')
          call wr%write('Gamma_1', md%cf%Gamma_1(md%x))
       case ('nabla_ad')
          call wr%write('nabla_ad', md%cf%nabla_ad(md%x))
       case ('delta')
          call wr%write('delta', md%cf%delta(md%x))
       case ('xi_r')
          call wr%write('xi_r', md%xi_r())
       case ('xi_h')
          call wr%write('xi_h', md%xi_h())
       case ('Yt_1')
          call wr%write('Yt_1', md%Yt_1())
       case ('Yt_2')
          call wr%write('Yt_2', md%Yt_2())
       case ('phip')
          call wr%write('phip', md%phip())
       case ('dphip_dx')
          call wr%write('dphip_dx', md%dphip_dx())
       case ('delS')
          call wr%write('delS', md%delS())
       case ('delS_en')
          call wr%write('delS_en', md%delS_en())
       case ('delL')
          call wr%write('delL', md%delL())
       case ('delL_rd')
          call wr%write('delL_rd', md%delL_rd())
       case ('delp')
          call wr%write('delp', md%delp())
       case ('delrho')
          call wr%write('delrho', md%delrho())
       case ('delT')
          call wr%write('delT', md%delT())
       case ('dE_dx')
          call wr%write('dE_dx', md%dE_dx())
       case ('dW_dx')
          call wr%write('dW_dx', md%dW_dx())
       case ('I_0')
          call wr%write('I_0', md%I_0())
       case ('I_1')
          call wr%write('I_1', md%I_1())
       case ('prop_type')
          call wr%write('prop_type', md%prop_type())
       case ('K')
          call wr%write('K', md%K())
       case default
          select type (cf => md%cf)
          type is (evol_coeffs_t)
             call write_mode_evol(wr, cf, items(j))
          type is (poly_coeffs_t)
             call write_mode_poly(wr, cf, items(j))
          class default
             write(ERROR_UNIT, *) 'item:', TRIM(items(j))
             $ABORT(Invalid item)
          end select
       end select

    end do item_loop

    ! Finish

    return

  contains

    subroutine write_mode_evol (wr, ec, item)

      class(writer_t), intent(inout)  :: wr
      type(evol_coeffs_t), intent(in) :: ec
      character(LEN=*), intent(in)    :: item

      ! Write the item

      select case (item)
      case ('M_star')
         call wr%write('M_star', ec%M_star)
      case ('R_star')
         call wr%write('R_star', ec%R_star)
      case ('L_star')
         call wr%write('L_star', ec%L_star)
      case ('m')
         call wr%write('m', ec%m(md%x))
      case ('p')
         call wr%write('p', ec%p(md%x))
      case ('rho')
         call wr%write('rho', ec%rho(md%x))
      case ('T')
         call wr%write('T', ec%T(md%x))
      case default
         write(ERROR_UNIT, *) 'item:', TRIM(item)
         $ABORT(Invalid item)
      end select

      ! Finish

      return

    end subroutine write_mode_evol

    subroutine write_mode_poly (wr, pc, item)

      class(writer_t), intent(inout)  :: wr
      type(poly_coeffs_t), intent(in) :: pc
      character(LEN=*), intent(in)    :: item

      ! Write the item

      select case (item)
      case ('n_poly')
         call wr%write('n_poly', pc%n_poly)
      case default
         write(ERROR_UNIT, *) 'item:', TRIM(item)
         $ABORT(Invalid item)
      end select

      ! Finish

      return

    end subroutine write_mode_poly

  end subroutine write_mode

end module gyre_output
