# frozen_string_literal: true

require 'scrappers/fandoms/skills_weapons'

# Minimal stand-in for Scrappers::Fandom, which is the only class that
# actually includes SkillsWeapons. It only needs to provide what the
# module relies on from its host: `errors` and `self.class::SKILL_CAT_WEAPON`.
class SkillsWeaponsHost
  SKILL_CAT_WEAPON = 'weapon'
  SKILL_CAT_SPECIAL = 'special'

  include Scrappers::Fandoms::SkillsWeapons

  attr_reader :errors

  def initialize
    @errors = Hash.new { |h, k| h[k] = [] }
  end
end

RSpec.describe Scrappers::Fandoms::SkillsWeapons do
  subject(:host) { SkillsWeaponsHost.new }

  describe '#sanitize_weapon_restriction' do
    # Every example in this file is a regression test against false-positive
    # weird-restriction errors, except the one below that's specifically about
    # producing one — so assert it's empty everywhere else, instead of relying on
    # each example to remember to check it.
    after do |example|
      next if example.metadata[:expects_weird_restriction_error]

      expect(host.errors[:skill_with_weird_weapon_restrictions]).to be_empty
    end

    it 'records an error when CanUseWeapon contains an unrecognized weapon' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => "#{described_class::WEAPON_R_SW}, Not A Weapon",
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      host.sanitize_weapon_restriction(skill)

      expect(host.errors[:skill_with_unknown_weapon_restrictions]).to eq(['Some Skill'])
    end

    it 'uses the given prefix to namespace the unknown-weapon error' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => 'Not A Weapon',
        'WikiName' => 'Some Seal',
        'Name' => 'Some Seal',
      }

      host.sanitize_weapon_restriction(skill, :seal)

      expect(host.errors[:seal_with_unknown_weapon_restrictions]).to eq(['Some Seal'])
      expect(host.errors[:skill_with_unknown_weapon_restrictions]).to be_empty
    end

    it 'returns none when every weapon is usable' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => described_class::ALL_WEAPONS.join(', '),
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(none: true)
    end

    it 'returns can_not_use Colorless Staff when it is the only excluded weapon' do
      can_use = described_class::ALL_WEAPONS - [described_class::WEAPON_C_ST]
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => can_use.join(', '),
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(can_not_use: [described_class::WEAPON_C_ST])
    end

    it 'returns can_use Red when usable weapons are exactly all the red weapons' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => described_class::ALL_REDS.join(', '),
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_R])
    end

    it 'returns can_not_use Blue when every weapon but blue ones is usable' do
      can_use = described_class::ALL_WEAPONS - described_class::ALL_BLUES
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => can_use.join(', '),
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(can_not_use: [described_class::WEAPON_B])
    end

    it 'returns can_use All Melee when usable weapons are exactly the three melee weapons' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => described_class::ALL_MELEE.join(', '),
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_MELEE])
    end

    it 'returns can_use with the single melee weapon when only part of melee is usable' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => described_class::WEAPON_R_SW,
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_R_SW])
    end

    it 'records a weird-restriction error, with the raw CanUseWeapon, when a family singles out a ' \
       'still-otherwise-usable color', :expects_weird_restriction_error do
      # Red is fully usable and Blue is usable everywhere except its Bow: since
      # neither color is entirely excluded, that gap can't be explained away, unlike
      # a Feud/Duel/Triangle Adept-style whole-color exclusion.
      can_use = described_class::ALL_REDS + (described_class::ALL_BLUES - [described_class::WEAPON_B_BO])
      can_use_weapon = can_use.join(', ')

      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => can_use_weapon,
        'WikiName' => 'Some Skill',
        'Name' => 'Some Skill',
      }

      host.sanitize_weapon_restriction(skill)

      expect(host.errors[:skill_with_weird_weapon_restrictions]).to eq(
        [['Some Skill', described_class::ALL_BOWS, described_class::WEAPON_A_BO, can_use_weapon]],
      )
    end

    it 'does not record a weird-restriction error for Cancel Affinity skills' do
      skill = {
        'GroupName' => 'Cancel Affinity',
        'CanUseWeapon' => [described_class::WEAPON_R_BO, described_class::WEAPON_B_BO].join(', '),
        'WikiName' => 'Cancel Affinity (Bow)',
        'Name' => 'Cancel Affinity (Bow)',
      }

      host.sanitize_weapon_restriction(skill)

      expect(host.errors[:skill_with_weird_weapon_restrictions]).to be_empty
    end

    it 'does not record a weird-restriction error for a partial Tome color split' do
      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => described_class::WEAPON_R_TO,
        'WikiName' => 'Argent Aura',
        'Name' => 'Argent Aura',
      }

      host.sanitize_weapon_restriction(skill)

      expect(host.errors[:skill_with_weird_weapon_restrictions]).to be_empty
    end

    it 'does not record a weird-restriction error for a skill excluding one entire color' do
      # e.g. Triangle Adept, Axebreaker, Swordbreaker: every family they touch is
      # incomplete only because Colorless is entirely excluded, which isn't weird.
      can_use = described_class::ALL_WEAPONS - described_class::ALL_COLORLESS

      skill = {
        'GroupName' => 'Whatever',
        'CanUseWeapon' => can_use.join(', '),
        'WikiName' => 'Some Triangle Skill',
        'Name' => 'Some Triangle Skill',
      }

      host.sanitize_weapon_restriction(skill)

      expect(host.errors[:skill_with_weird_weapon_restrictions]).to be_empty
    end

    context 'with real Duel Flying skills' do
      it 'R Duel Flying 3 can only be used by Red units' do
        skill = {
          'GroupName' => 'R Duel Flying',
          'CanUseWeapon' => 'Red Sword,  Red Bow,  Red Dagger,  Red Tome,  Red Breath,  Red Beast',
          'WikiName' => 'R Duel Flying 3',
          'Name' => 'R Duel Flying 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_R])
      end

      it 'B Duel Flying 3 can only be used by Blue units' do
        skill = {
          'GroupName' => 'B Duel Flying',
          'CanUseWeapon' => 'Blue Lance,  Blue Bow,  Blue Dagger,  Blue Tome,  Blue Breath,  Blue Beast',
          'WikiName' => 'B Duel Flying 3',
          'Name' => 'B Duel Flying 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_B])
      end

      it 'G Duel Flying 3 can only be used by Green units' do
        skill = {
          'GroupName' => 'G Duel Flying',
          'CanUseWeapon' => 'Green Axe,  Green Bow,  Green Dagger,  Green Tome,  Green Breath,  Green Beast',
          'WikiName' => 'G Duel Flying 3',
          'Name' => 'G Duel Flying 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_G])
      end

      it 'C Duel Flying 3 can only be used by Colorless units' do
        skill = {
          'GroupName' => 'C Duel Flying',
          'CanUseWeapon' => 'Colorless Bow,  Colorless Dagger,  Colorless Tome,  Colorless Staff,  ' \
                            'Colorless Breath,  Colorless Beast',
          'WikiName' => 'C Duel Flying 3',
          'Name' => 'C Duel Flying 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_C])
      end
    end

    context 'with real Feud skills' do
      it 'Red Feud 3 cannot be used by Green units' do
        skill = {
          'GroupName' => 'Red Feud',
          'CanUseWeapon' => 'Red Sword,  Blue Lance,  Red Bow,  Blue Bow,  Colorless Bow,  Red Dagger,  ' \
                            'Blue Dagger,  Colorless Dagger,  Red Tome,  Blue Tome,  Colorless Tome,  ' \
                            'Colorless Staff,  Red Breath,  Blue Breath,  Colorless Breath,  Red Beast,  ' \
                            'Blue Beast,  Colorless Beast',
          'WikiName' => 'Red Feud 3',
          'Name' => 'Red Feud 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_not_use: [described_class::WEAPON_G])
      end

      it 'Blue Feud 3 cannot be used by Red units' do
        skill = {
          'GroupName' => 'Blue Feud',
          'CanUseWeapon' => 'Blue Lance,  Green Axe,  Blue Bow,  Green Bow,  Colorless Bow,  Blue Dagger,  ' \
                            'Green Dagger,  Colorless Dagger,  Blue Tome,  Green Tome,  Colorless Tome,  ' \
                            'Colorless Staff,  Blue Breath,  Green Breath,  Colorless Breath,  Blue Beast,  ' \
                            'Green Beast,  Colorless Beast',
          'WikiName' => 'Blue Feud 3',
          'Name' => 'Blue Feud 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_not_use: [described_class::WEAPON_R])
      end

      it 'Green Feud 3 cannot be used by Blue units' do
        skill = {
          'GroupName' => 'Green Feud',
          'CanUseWeapon' => 'Red Sword,  Green Axe,  Red Bow,  Green Bow,  Colorless Bow,  Red Dagger,  ' \
                            'Green Dagger,  Colorless Dagger,  Red Tome,  Green Tome,  Colorless Tome,  ' \
                            'Colorless Staff,  Red Breath,  Green Breath,  Colorless Breath,  Red Beast,  ' \
                            'Green Beast,  Colorless Beast',
          'WikiName' => 'Green Feud 3',
          'Name' => 'Green Feud 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_not_use: [described_class::WEAPON_B])
      end

      it 'C Feud 3 has no restriction' do
        skill = {
          'GroupName' => 'C Feud',
          'CanUseWeapon' => described_class::ALL_WEAPONS.join(', '),
          'WikiName' => 'C Feud 3',
          'Name' => 'C Feud 3',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(none: true)
      end
    end

    context 'can_use with a class of weapons' do
      it 'Counter Dull can be used by melee units' do
        skill = {
          'GroupName' => 'Counter Dull',
          'CanUseWeapon' => 'Red Sword,  Blue Lance,  Green Axe',
          'WikiName' => 'Counter Dull',
          'Name' => 'Counter Dull',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_MELEE])
      end

      it 'Waning Shot can be used by bow units' do
        skill = {
          'GroupName' => 'Waning Shot',
          'CanUseWeapon' => 'Red Bow,  Blue Bow,  Green Bow,  Colorless Bow',
          'WikiName' => 'Waning Shot',
          'Name' => 'Waning Shot',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_BO])
      end

      it 'Lookout Rush can be used by dagger units' do
        skill = {
          'GroupName' => 'Lookout Rush',
          'CanUseWeapon' => 'Red Dagger,  Blue Dagger,  Green Dagger,  Colorless Dagger',
          'WikiName' => 'Lookout Rush',
          'Name' => 'Lookout Rush',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_DA])
      end

      it 'Demonic Force can be used by tome units' do
        skill = {
          'GroupName' => 'Demonic Force',
          'CanUseWeapon' => 'Red Tome,  Blue Tome,  Green Tome,  Colorless Tome',
          'WikiName' => 'Demonic Force',
          'Name' => 'Demonic Force',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_TO])
      end

      it 'Distant Breath can be used by breath (dragon) units' do
        skill = {
          'GroupName' => 'Distant Breath',
          'CanUseWeapon' => 'Red Breath,  Blue Breath,  Green Breath,  Colorless Breath',
          'WikiName' => 'Distant Breath',
          'Name' => 'Distant Breath',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_BR])
      end

      it 'Dark Beast Agility can be used by beast units' do
        skill = {
          'GroupName' => 'Dark Beast Agility',
          'CanUseWeapon' => 'Red Beast,  Blue Beast,  Green Beast,  Colorless Beast',
          'WikiName' => 'Dark Beast Agility',
          'Name' => 'Dark Beast Agility',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(can_use: [described_class::WEAPON_A_BE])
      end
    end

    context 'with real skills mixing weapon and color families' do
      it 'Azure Impetus cannot be used by Red, Bow, Dagger, Tome, or Colorless Staff units' do
        can_use = described_class::ALL_WEAPONS
        can_use -= described_class::ALL_REDS
        can_use -= described_class::ALL_BOWS
        can_use -= described_class::ALL_DAGGERS
        can_use -= described_class::ALL_TOMES
        can_use -= [described_class::WEAPON_C_ST]

        skill = {
          'GroupName' => 'Whatever',
          'CanUseWeapon' => can_use.join(', '),
          'WikiName' => 'Azure Impetus',
          'Name' => 'Azure Impetus',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(
          can_not_use: [
            described_class::WEAPON_R,
            described_class::WEAPON_A_BO,
            described_class::WEAPON_A_DA,
            described_class::WEAPON_A_TO,
            described_class::WEAPON_C_ST,
          ],
        )
      end

      it 'Crimson Impetus cannot be used by Green, Bow, Dagger, Tome, or Colorless Staff units' do
        can_use = described_class::ALL_WEAPONS
        can_use -= described_class::ALL_GREENS
        can_use -= described_class::ALL_BOWS
        can_use -= described_class::ALL_DAGGERS
        can_use -= described_class::ALL_TOMES
        can_use -= [described_class::WEAPON_C_ST]

        skill = {
          'GroupName' => 'Whatever',
          'CanUseWeapon' => can_use.join(', '),
          'WikiName' => 'Crimson Impetus',
          'Name' => 'Crimson Impetus',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(
          can_not_use: [
            described_class::WEAPON_G,
            described_class::WEAPON_A_BO,
            described_class::WEAPON_A_DA,
            described_class::WEAPON_A_TO,
            described_class::WEAPON_C_ST,
          ],
        )
      end

      it 'Vivace can be used by melee, breath, and beast units' do
        can_use = described_class::ALL_WEAPONS
        can_use -= described_class::ALL_BOWS
        can_use -= described_class::ALL_DAGGERS
        can_use -= described_class::ALL_TOMES
        can_use -= [described_class::WEAPON_C_ST]

        skill = {
          'GroupName' => 'Whatever',
          'CanUseWeapon' => can_use.join(', '),
          'WikiName' => 'Vivace',
          'Name' => 'Vivace',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(
          can_use: [
            described_class::WEAPON_A_MELEE,
            described_class::WEAPON_A_BR,
            described_class::WEAPON_A_BE,
          ],
        )
      end

      it 'Arms Shield 4 cannot be used by Colorless, Tome, or Breath units' do
        skill = {
          'GroupName' => 'Arms Shield',
          'CanUseWeapon' => 'Red Sword,  Blue Lance,  Green Axe,  Red Bow,  Blue Bow,  Green Bow,  ' \
                            'Red Dagger,  Blue Dagger,  Green Dagger,  Red Beast,  Blue Beast,  Green Beast',
          'WikiName' => 'Arms Shield 4',
          'Name' => 'Arms Shield 4',
        }

        expect(host.sanitize_weapon_restriction(skill)).to eq(
          can_not_use: [described_class::WEAPON_C, described_class::WEAPON_A_TO, described_class::WEAPON_A_BR],
        )
      end
    end

    context 'with a real Cancel Affinity skill' do
      it 'Cancel Affinity 3 can be used by melee, breath, beast, and colorless bow/dagger/tome units' do
        skill = {
          'GroupName' => 'Cancel Affinity',
          'CanUseWeapon' => 'Red Sword,  Blue Lance,  Green Axe,  Colorless Bow,  Colorless Dagger,  ' \
                            'Colorless Tome,  Red Breath,  Blue Breath,  Green Breath,  Colorless Breath,  ' \
                            'Red Beast,  Blue Beast,  Green Beast,  Colorless Beast',
          'WikiName' => 'Cancel Affinity 3',
          'Name' => 'Cancel Affinity 3',
        }

        result = host.sanitize_weapon_restriction(skill)

        expect(result).to eq(
          can_use: [
            described_class::WEAPON_A_MELEE,
            described_class::WEAPON_A_BR,
            described_class::WEAPON_A_BE,
            described_class::WEAPON_C_BO,
            described_class::WEAPON_C_DA,
            described_class::WEAPON_C_TO,
          ],
        )
      end
    end
  end

  describe '#sanitize_weapon_type' do
    it 'returns nil for a skill that is not a weapon' do
      skill = { 'Scategory' => SkillsWeaponsHost::SKILL_CAT_SPECIAL, 'CanUseWeapon' => described_class::WEAPON_R_SW }

      expect(host.sanitize_weapon_type(skill)).to be_nil
    end

    it 'returns the single usable weapon for an exclusive weapon' do
      skill = {
        'Scategory' => SkillsWeaponsHost::SKILL_CAT_WEAPON,
        'CanUseWeapon' => described_class::WEAPON_R_SW,
        'WikiName' => 'Some Sword',
      }

      expect(host.sanitize_weapon_type(skill)).to eq(described_class::WEAPON_R_SW)
    end

    {
      'Bow' => :ALL_BOWS,
      'Dagger' => :ALL_DAGGERS,
      'Tome' => :ALL_TOMES,
      'Breath' => :ALL_BREATHES,
      'Beast' => :ALL_BEASTS,
    }.each do |kind, all_const|
      it "returns All #{kind} when every #{kind.downcase} is usable" do
        all = described_class.const_get(all_const)
        skill = {
          'Scategory' => SkillsWeaponsHost::SKILL_CAT_WEAPON,
          'CanUseWeapon' => all.join(', '),
          'WikiName' => "Some #{kind}",
        }

        expect(host.sanitize_weapon_type(skill)).to eq(described_class.const_get(:"WEAPON_A_#{kind[0, 2].upcase}"))
      end
    end

    it 'records an error and does not resolve a type for an unresolvable combination' do
      skill = {
        'Scategory' => SkillsWeaponsHost::SKILL_CAT_WEAPON,
        'CanUseWeapon' => [described_class::WEAPON_R_SW, described_class::WEAPON_B_LA].join(', '),
        'WikiName' => 'Some Weapon',
      }

      host.sanitize_weapon_type(skill)

      expect(host.errors[:not_sanitizable_weapon_type]).to eq(['Some Weapon'])
    end
  end
end
